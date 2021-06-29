import pytest

from brownie import chain, reverts, web3
from brownie.test import given, strategy
from collections import OrderedDict


MIN_COLLATERAL_AMOUNT = 10**4  # min amount to build
TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000
FEE_RESOLUTION = 1e4


@given(
    oi_long=strategy('uint256',
                     min_value=MIN_COLLATERAL_AMOUNT,
                     max_value=0.999*OI_CAP*10**TOKEN_DECIMALS),
    oi_short=strategy('uint256',
                      min_value=MIN_COLLATERAL_AMOUNT,
                      max_value=0.999*OI_CAP*10**TOKEN_DECIMALS),
    num_periods=strategy('uint16', min_value=1, max_value=144),
)
def test_update(token,
                factory,
                market,
                alice,
                bob,
                rewards,
                oi_long,
                oi_short,
                num_periods):
    update_period = market.updatePeriod()

    # queue up bob's positions to be settled at next update (T+1)
    # 1x long w oi_long as collateral and 1x short with oi_short
    token.approve(market, oi_long+oi_short, {"from": bob})

    # do an initial update before build so all oi is queued
    market.update(rewards, {"from": alice})

    # build so all oi is queued
    # TODO: check no issues when some queued, some settled
    market.build(oi_long, True, 1, bob, {"from": bob})
    market.build(oi_short, False, 1, bob, {"from": bob})

    # prior fee state
    _, fee_burn_rate, fee_reward_rate, fee_to = factory.getUpdateParams()
    prior_fees = market.fees()

    # prior token balances
    prior_balance_market = token.balanceOf(market)
    prior_balance_fee_to = token.balanceOf(fee_to)
    prior_balance_rewards_to = token.balanceOf(rewards)
    prior_total_supply = token.totalSupply()

    # prior oi state
    prior_queued_oi_long = market.queuedOiLong()
    prior_queued_oi_short = market.queuedOiShort()
    prior_oi_long = market.oiLong()
    prior_oi_short = market.oiShort()

    # prior price point state
    prior_price_point_idx = market.pricePointCurrentIndex()

    # Calc reward rate before update
    reward_perc = fee_reward_rate / FEE_RESOLUTION
    expected_fee_reward = int(reward_perc * prior_fees)

    start_block = chain[-1]['number']
    chain.mine(update_period+1)

    tx = market.update(rewards, {"from": alice})
    curr_update_block = market.updateBlockLast()

    # plus another 1 since tx will mine a block
    prior_plus_updates = start_block + update_period + 2
    assert curr_update_block == prior_plus_updates

    # check update event attrs
    assert 'Update' in tx.events
    assert tx.events['Update']['rewarded'] == rewards.address
    assert tx.events['Update']['reward'] == expected_fee_reward or expected_fee_reward - 1

    # Check queued OI settled
    expected_oi_long = prior_queued_oi_long + prior_oi_long
    expected_oi_short = prior_queued_oi_short + prior_oi_short
    curr_queued_oi_long = market.queuedOiLong()
    curr_queued_oi_short = market.queuedOiShort()
    curr_oi_long = market.oiLong()
    curr_oi_short = market.oiShort()

    assert curr_queued_oi_long == 0
    assert curr_queued_oi_short == 0
    assert curr_oi_long == expected_oi_long
    assert curr_oi_short == expected_oi_short

    curr_oi_imb = curr_oi_long - curr_oi_short
    curr_oi_tot = curr_oi_long + curr_oi_short

    # Check price points updated ...
    expected_price_point_idx = prior_price_point_idx + 1
    curr_price_point_idx = market.pricePointCurrentIndex()
    assert curr_price_point_idx == expected_price_point_idx

    # ... and price has settled
    assert market.pricePoints(prior_price_point_idx) > 0

    # Check fee burn ...
    expected_fee_burn = int(prior_fees * fee_burn_rate / FEE_RESOLUTION)
    expected_total_supply = prior_total_supply - expected_fee_burn
    assert token.totalSupply() == expected_total_supply or expected_total_supply + 1

    # ... and rewards sent to address to be rewarded
    expected_balance_rewards_to = prior_balance_rewards_to + expected_fee_reward
    assert token.balanceOf(rewards) == expected_balance_rewards_to or expected_balance_rewards_to - 1

    # ... and fees forwarded
    expected_balance_market = prior_balance_market - prior_fees
    expected_fee_forward = prior_fees - expected_fee_burn - expected_fee_reward
    expected_balance_fee_to = prior_balance_fee_to + expected_fee_forward
    assert token.balanceOf(fee_to) == expected_balance_fee_to or expected_balance_fee_to - 1
    assert token.balanceOf(market) == expected_balance_market

    # Check cumulative fee pot zeroed
    assert market.fees() == 0

    # Now do a longer update ...
    curr_block = chain[-1]['number']
    update_blocks = num_periods * update_period
    chain.mine(update_blocks)

    tx = market.update(rewards, {"from": alice})
    next_update_block = market.updateBlockLast()

    # plus 1 since tx will mine a block
    curr_plus_updates = curr_block + update_blocks + 1
    assert next_update_block == curr_plus_updates

    # check update event attrs
    assert 'Update' in tx.events
    assert tx.events['Update']['rewarded'] == rewards.address
    assert tx.events['Update']['reward'] == 0  # rewarded 0 since no positions built

    # check funding payments over longer period
    k = market.fundingKNumerator() / market.fundingKDenominator()
    expected_oi_imb = curr_oi_imb * (1 - 2*k)**num_periods
    expected_oi_long = int((curr_oi_tot + expected_oi_imb) / 2)
    expected_oi_short = int((curr_oi_tot - expected_oi_imb) / 2)

    next_oi_long = market.oiLong()
    next_oi_short = market.oiShort()

    assert next_oi_long == expected_oi_long or expected_oi_long - 1
    assert next_oi_short == expected_oi_short or expected_oi_short - 1


def test_update_funding_burn():
    pass


def test_update_funding_k():
    # TODO: test for different k values via an adjust
    pass


def test_update_early():
    # TODO: number of update periods have gone by is zero so nothing
    # should happen to state
    pass


def test_update_between_periods(token, factory, market, alice, rewards):
    update_period = market.updatePeriod()
    update_blocks = update_period
    prior_update_block = market.updateBlockLast()

    latest_block = chain[-1]['number']
    if int((latest_block - prior_update_block) / update_period) > 0:
        market.update(rewards, {"from": alice})
        latest_block = chain[-1]['number']
        prior_update_block = market.updateBlockLast()

    blocks_to_mine = update_period - (latest_block - prior_update_block) - 2

    chain.mine(blocks_to_mine)

    # Should not update since update period hasn't passed yet
    market.update(rewards, {"from": alice})

    curr_update_block = market.updateBlockLast()
    assert curr_update_block == prior_update_block


def test_update_max_compound(token, factory, market, alice, rewards):
    pass
