"""Tests for calculator module."""

import pytest
from calculator import add, subtract, multiply, divide, is_even, is_odd


class TestArithmetic:
    """Test arithmetic operations."""

    def test_add(self):
        """Test addition."""
        assert add(2, 3) == 5
        assert add(-1, 1) == 0
        assert add(0, 0) == 0

    def test_subtract(self):
        """Test subtraction."""
        assert subtract(5, 3) == 2
        assert subtract(1, 1) == 0
        assert subtract(0, 5) == -5

    def test_multiply(self):
        """Test multiplication."""
        assert multiply(3, 4) == 12
        assert multiply(0, 10) == 0
        assert multiply(-2, 3) == -6

    def test_divide(self):
        """Test division."""
        assert divide(10, 2) == 5
        assert divide(9, 3) == 3
        assert divide(1, 2) == 0.5

    def test_divide_by_zero(self):
        """Test division by zero raises error."""
        with pytest.raises(ValueError, match="Cannot divide by zero"):
            divide(10, 0)


class TestNumberChecks:
    """Test number checking functions."""

    def test_is_even(self):
        """Test even number detection."""
        assert is_even(2) is True
        assert is_even(4) is True
        assert is_even(0) is True
        assert is_even(3) is False
        assert is_even(7) is False

    def test_is_odd(self):
        """Test odd number detection."""
        assert is_odd(1) is True
        assert is_odd(3) is True
        assert is_odd(7) is True
        assert is_odd(2) is False
        assert is_odd(0) is False
