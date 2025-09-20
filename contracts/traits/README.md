# Conxian Protocol - Traits

## Centralized Trait Definitions
All traits are now defined in a single file for consistency and maintainability:
- `all-traits.clar` - Contains all trait definitions

## Deprecation Notice
Individual trait files have been deprecated in favor of the centralized `all-traits.clar` file. 
Please update your contracts to reference traits from this file.

## Migration Guide
1. Replace any imports of individual trait files with:
   `(use-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.<trait-name>)`
2. Update trait references to use standardized names
3. Remove any local trait definitions
