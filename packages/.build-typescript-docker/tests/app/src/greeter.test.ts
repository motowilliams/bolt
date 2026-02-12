import { Greeter } from './greeter';

describe('Greeter', () => {
  let greeter: Greeter;

  beforeEach(() => {
    greeter = new Greeter();
  });

  describe('greet', () => {
    it('should return default greeting when no name is provided', () => {
      expect(greeter.greet()).toBe('Hello, World!');
    });

    it('should return default greeting when empty string is provided', () => {
      expect(greeter.greet('')).toBe('Hello, World!');
    });

    it('should return default greeting when whitespace string is provided', () => {
      expect(greeter.greet('   ')).toBe('Hello, World!');
    });

    it('should return personalized greeting when name is provided', () => {
      expect(greeter.greet('Alice')).toBe('Hello, Alice!');
    });

    it('should trim whitespace from names', () => {
      expect(greeter.greet('  Bob  ')).toBe('Hello, Bob!');
    });
  });

  describe('farewell', () => {
    it('should return default farewell when no name is provided', () => {
      expect(greeter.farewell()).toBe('Goodbye, World!');
    });

    it('should return default farewell when empty string is provided', () => {
      expect(greeter.farewell('')).toBe('Goodbye, World!');
    });

    it('should return personalized farewell when name is provided', () => {
      expect(greeter.farewell('Charlie')).toBe('Goodbye, Charlie!');
    });

    it('should trim whitespace from names', () => {
      expect(greeter.farewell('  David  ')).toBe('Goodbye, David!');
    });
  });
});
