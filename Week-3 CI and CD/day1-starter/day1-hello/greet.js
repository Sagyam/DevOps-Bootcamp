// A deliberately tiny program. Day 1 is about the *workflow* around code,
// not the code itself. This just proves a step actually ran and can read
// data the workflow handed it.

const who = process.env.GREET_NAME || "world";
const runNumber = process.env.GITHUB_RUN_NUMBER || "local";

console.log(`Hello, ${who}! This is run #${runNumber}.`);
