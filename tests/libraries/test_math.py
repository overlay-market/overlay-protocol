import pytest
import brownie

from brownie.test import given, strategy


ACCURACY = 1e-9  # 0.00001 bps acceptable error


@given(
    nx=strategy('uint144'),
    dx=strategy('uint112', exclude=0),
    ny=strategy('uint144'),
    dy=strategy('uint112', exclude=0))
def test_mul(math, nx, dx, ny, dy):
    x = nx / dx
    y = ny / dy

    mul = int(x * y)
    math_mul = math.mul(nx, dx, ny, dy)

    diff = abs(math_mul - mul)
    err = mul * ACCURACY
    assert diff <= err


@given(
    nx=strategy('uint144'),
    dx=strategy('uint112', exclude=0),
    ny=strategy('uint144', exclude=0),
    dy=strategy('uint112', exclude=0))
def test_div(math, nx, dx, ny, dy):
    x = nx / dx
    y = ny / dy

    div = int(x / y)
    math_div = math.div(nx, dx, ny, dy)

    diff = abs(math_div - div)
    err = div * ACCURACY
    assert diff <= err


@given(
    nx=strategy('uint144'),
    dx=strategy('uint112', exclude=0),
    ny=strategy('uint144'),
    dy=strategy('uint112', exclude=0))
def test_lt(math, nx, dx, ny, dy):
    x = nx / dx
    y = ny / dy
    is_lt = x < y
    assert math.lt(nx, dx, ny, dy) is is_lt


@given(
    nx=strategy('uint144'),
    dx=strategy('uint112', exclude=0),
    ny=strategy('uint144'),
    dy=strategy('uint112', exclude=0))
def test_gt(math, nx, dx, ny, dy):
    x = nx / dx
    y = ny / dy
    is_gt = x > y
    assert math.gt(nx, dx, ny, dy) is is_gt


@given(
    numerator=strategy('uint144'),
    denominator=strategy('uint112', exclude=0),
    n=strategy('uint'))
def test_pow(math, numerator, denominator, n):
    b = numerator / denominator

    pow = int(b ** n)
    math_pow = math.pow(numerator, denominator, n)

    diff = abs(math_pow - pow)
    err = pow * ACCURACY
    assert diff <= err


@given(
    p=strategy('uint144'),
    f=strategy('decimal', min_value='0', max_value='1'),
    n=strategy('uint16'))
def test_compound(math, p, f, n):
    numerator, denominator = f.as_integer_ratio()

    comp = int(p * ((numerator / denominator) ** n))
    math_comp = math.compound(p, numerator, denominator, n)

    diff = abs(math_comp - comp)
    err = comp * ACCURACY
    assert diff <= err
