/**
 * Greeter class that provides greeting functionality
 */
export class Greeter {
  /**
   * Creates a greeting message for the given name
   * @param name - The name to greet (optional)
   * @returns A greeting message
   */
  greet(name?: string): string {
    if (!name || name.trim() === '') {
      return 'Hello, World!';
    }
    return `Hello, ${name.trim()}!`;
  }

  /**
   * Creates a farewell message for the given name
   * @param name - The name to bid farewell (optional)
   * @returns A farewell message
   */
  farewell(name?: string): string {
    if (!name || name.trim() === '') {
      return 'Goodbye, World!';
    }
    return `Goodbye, ${name.trim()}!`;
  }
}

export default Greeter;
