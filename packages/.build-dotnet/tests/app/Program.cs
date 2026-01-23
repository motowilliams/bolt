namespace HelloWorld;

public class Calculator
{
    public int Add(int a, int b)
    {
        return a + b;
    }

    public int Subtract(int a, int b)
    {
        return a - b;
    }

    public int Multiply(int a, int b)
    {
        return a * b;
    }

    public double Divide(int a, int b)
    {
        if (b == 0)
        {
            throw new DivideByZeroException("Cannot divide by zero");
        }
        return (double)a / b;
    }
}

public class Program
{
    public static void Main(string[] args)
    {
        var calculator = new Calculator();

        Console.WriteLine("Hello, World from .NET!");
        Console.WriteLine($"2 + 3 = {calculator.Add(2, 3)}");
        Console.WriteLine($"10 - 4 = {calculator.Subtract(10, 4)}");
        Console.WriteLine($"5 * 6 = {calculator.Multiply(5, 6)}");
        Console.WriteLine($"15 / 3 = {calculator.Divide(15, 3)}");
    }
}
