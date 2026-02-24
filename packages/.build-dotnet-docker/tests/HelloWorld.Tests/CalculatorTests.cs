using Xunit;

namespace HelloWorld.Tests;

public class CalculatorTests
{
    private readonly Calculator _calculator;

    public CalculatorTests()
    {
        _calculator = new Calculator();
    }

    [Fact]
    public void Add_TwoPositiveNumbers_ReturnsCorrectSum()
    {
        // Arrange
        int a = 5;
        int b = 3;

        // Act
        var result = _calculator.Add(a, b);

        // Assert
        Assert.Equal(8, result);
    }

    [Fact]
    public void Add_NegativeAndPositive_ReturnsCorrectSum()
    {
        // Arrange
        int a = -5;
        int b = 10;

        // Act
        var result = _calculator.Add(a, b);

        // Assert
        Assert.Equal(5, result);
    }

    [Fact]
    public void Subtract_TwoNumbers_ReturnsCorrectDifference()
    {
        // Arrange
        int a = 10;
        int b = 4;

        // Act
        var result = _calculator.Subtract(a, b);

        // Assert
        Assert.Equal(6, result);
    }

    [Fact]
    public void Multiply_TwoNumbers_ReturnsCorrectProduct()
    {
        // Arrange
        int a = 5;
        int b = 6;

        // Act
        var result = _calculator.Multiply(a, b);

        // Assert
        Assert.Equal(30, result);
    }

    [Fact]
    public void Divide_ValidNumbers_ReturnsCorrectQuotient()
    {
        // Arrange
        int a = 15;
        int b = 3;

        // Act
        var result = _calculator.Divide(a, b);

        // Assert
        Assert.Equal(5.0, result);
    }

    [Fact]
    public void Divide_ByZero_ThrowsDivideByZeroException()
    {
        // Arrange
        int a = 10;
        int b = 0;

        // Act & Assert
        Assert.Throws<DivideByZeroException>(() => _calculator.Divide(a, b));
    }
}
