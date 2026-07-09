// Pure validation, split out so it can be unit-tested with no database.

function validateTitle(title) {
  if (typeof title !== "string") return "title must be a string";
  const trimmed = title.trim();
  if (trimmed.length === 0) return "title must not be empty";
  if (trimmed.length > 200) return "title must be 200 characters or fewer";
  return null; // null means "valid"
}

module.exports = { validateTitle };
