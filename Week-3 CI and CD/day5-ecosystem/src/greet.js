// Deliberately boring. Day 5 is about the *pipeline around* the code,
// not the code. It just needs a lint target and a test target.
function greet(name) {
  if (!name) throw new Error("name is required");
  return `Hello, ${name}!`;
}

module.exports = { greet };
