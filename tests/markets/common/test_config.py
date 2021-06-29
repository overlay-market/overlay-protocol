import re


TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000
AMOUNT_IN = 1


def test_balances(token, gov, rewards, alice, bob, feed_owner):
    assert token.totalSupply() == token.balanceOf(bob)
    assert token.balanceOf(gov) == 0
    assert token.balanceOf(rewards) == 0
    assert token.balanceOf(alice) == 0
    assert token.balanceOf(feed_owner) == 0


def test_roles(token, gov, feed_owner, factory, market, alice, bob):
    assert token.hasRole(token.ADMIN_ROLE(), gov) is True
    assert token.hasRole(token.MINTER_ROLE(), feed_owner) is False
    assert token.hasRole(token.BURNER_ROLE(), feed_owner) is False

    assert token.hasRole(token.ADMIN_ROLE(), factory) is True
    assert token.hasRole(token.MINTER_ROLE(), factory) is False
    assert token.hasRole(token.BURNER_ROLE(), factory) is False

    assert token.hasRole(token.ADMIN_ROLE(), alice) is False
    assert token.hasRole(token.MINTER_ROLE(), alice) is False
    assert token.hasRole(token.BURNER_ROLE(), alice) is False

    assert token.hasRole(token.ADMIN_ROLE(), bob) is False
    assert token.hasRole(token.MINTER_ROLE(), bob) is False
    assert token.hasRole(token.MINTER_ROLE(), bob) is False

    assert token.hasRole(token.MINTER_ROLE(), market) is True
    assert token.hasRole(token.BURNER_ROLE(), market) is True
    assert token.hasRole(token.ADMIN_ROLE(), market) is False


def test_params(factory, market):
    # TODO: test all factory and market params set properly
    pass


def test_markets(factory, market):
    assert factory.allMarkets(0) == market.address
    assert market.marginAdjustment() == 100
    assert market.oiCap() == OI_CAP*10**TOKEN_DECIMALS


def test_market_is_enabled(factory, market):
    assert factory.isMarket(market) is True


def test_market_erc1155(market):
    match = re.fullmatch(
        r"https://metadata.overlay.exchange/v1/(\w+)/{id}.json",
        market.uri(0),
    )
    assert match is not None
