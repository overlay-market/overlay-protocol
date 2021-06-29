import pytest
from brownie import OverlayToken


@pytest.fixture(scope="module")
def gov(accounts):
    yield accounts[0]


@pytest.fixture(scope="module")
def alice(accounts):
    yield accounts[2]


@pytest.fixture(scope="module")
def bob(accounts):
    yield accounts[3]


@pytest.fixture(scope="module", params=[8000000])
def create_token(gov, alice, bob, request):
    sup = request.param

    def create_token(supply=sup):
        tok = gov.deploy(OverlayToken)
        tok.mint(gov, supply * 10 ** tok.decimals(), {"from": gov})
        tok.transfer(bob, supply * 10 ** tok.decimals(), {"from": gov})
        return tok

    yield create_token


@pytest.fixture(scope="module")
def token(create_token):
    yield create_token()


@pytest.fixture(scope="module")
def create_minter(token, gov, accounts):
    def create_minter(tok=token, governance=gov):
        tok.grantRole(tok.MINTER_ROLE(), accounts[7], {"from": gov})
        return accounts[7]

    yield create_minter


@pytest.fixture(scope="module")
def minter(create_minter):
    yield create_minter()


@pytest.fixture(scope="module")
def create_burner(token, gov, accounts):
    def create_burner(tok=token, governance=gov):
        tok.grantRole(tok.BURNER_ROLE(), accounts[8], {"from": gov})
        return accounts[8]

    yield create_burner


@pytest.fixture(scope="module")
def burner(create_burner):
    yield create_burner()


@pytest.fixture(scope="module")
def create_admin(token, gov, accounts):
    def create_admin(tok=token, governance=gov):
        tok.grantRole(tok.MINTER_ROLE(), accounts[9], {"from": gov})
        tok.grantRole(tok.BURNER_ROLE(), accounts[9], {"from": gov})
        return accounts[9]

    yield create_admin


@pytest.fixture(scope="module")
def admin(create_admin):
    yield create_admin()
