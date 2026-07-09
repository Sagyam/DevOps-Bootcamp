const { slugify } = require("../src/slug");

describe("slugify", () => {
  test("lowercases and hyphenates plain text", () => {
    expect(slugify("Hello World")).toBe("hello-world");
  });

  test("strips punctuation", () => {
    expect(slugify("It's a Trap!")).toBe("its-a-trap");
  });

  test("collapses repeated separators", () => {
    expect(slugify("a   b---c")).toBe("a-b-c");
  });

  test("trims leading and trailing separators", () => {
    expect(slugify("  --hello--  ")).toBe("hello");
  });

  test("keeps existing digits", () => {
    expect(slugify("Day 2 of 6")).toBe("day-2-of-6");
  });

  test("throws on non-string input", () => {
    expect(() => slugify(42)).toThrow(TypeError);
  });
});
