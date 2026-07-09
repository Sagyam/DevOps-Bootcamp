// A tiny, real utility: turn arbitrary text into a URL-safe slug.
// Small enough to read in one sitting, real enough to have edge cases
// worth testing — which is exactly what makes CI meaningful.

function slugify(input) {
  if (typeof input !== "string") {
    throw new TypeError("slugify expects a string");
  }

  return input
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, "") // drop anything that is not letter/number/space/hyphen
    .replace(/[\s-]+/g, "-") // collapse runs of space/hyphen into a single hyphen
    .replace(/^-+|-+$/g, ""); // trim leading/trailing hyphens
}

module.exports = { slugify };
