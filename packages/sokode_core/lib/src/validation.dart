/// Static structural defects a Level can have (spec §4).
enum ValidationError {
  dimensionOutOfBounds,
  noTargets,
  fewerCratesThanTargets,
  entityOutOfBounds,
  entityOnBlockedTile,
  duplicateCrate,
  playerOnCrate,
}

/// Result of RuleSet.validateStructure. Empty errors == valid.
class ValidationResult {
  const ValidationResult(this.errors);
  final List<ValidationError> errors;
  bool get isValid => errors.isEmpty;
}
