# JSHint Configuration

Create `.jshintrc`:

```json
{
  "node": true,
  "module": true,
  "esversion": 11,
  "camelcase": true,
  "curly": true,
  "eqeqeq": true,
  "forin": true,
  "immed": true,
  "indent": 2,
  "latedef": true,
  "newcap": true,
  "nonew": true,
  "quotmark": "single",
  "strict": false,
  "trailing": true,
  "undef": true,
  "unused": "vars",
  "asi": false
}
```

Notes:
- `"node": true` provides `process`, `console`, and other Node globals
- `"module": true` enables ESM import/export syntax
- `"strict": false` — ESM is always strict mode
- `"asi": false` enforces semicolons