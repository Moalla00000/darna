# Contributing to Darna

Thanks for helping improve Darna. This is a small DIY project, so short,
focused changes are easiest to review.

## Before you start

- Read the [README](README.md) for the hardware and setup flow.
- Do not commit real credentials. `backend/include/secrets.h`,
  `frontend/.env`, `key.properties`, and keystores are gitignored. Use the
  `.example` files for templates.
- For security issues, please do not open a public issue with exploit details;
  contact the maintainer privately first.

## Making a change

1. Fork the repository and create a branch:
   ```bash
   git checkout -b fix/short-description
   ```
2. Keep the change small and focused. Avoid unrelated refactors.
3. Do not change the pairing, token, or door-opening behavior unless the change
   is the point of the pull request — describe it clearly.
4. Run the checks:
   ```bash
   cd backend && pio run
   cd ../frontend && flutter analyze && flutter test
   ```
5. If you changed firmware behavior, test on real hardware and say what you
   tested.
6. Open a pull request with:
   - what changed and why,
   - how you tested it,
   - any known limitations.

## Style

- Firmware: keep the existing Arduino/C++ style, named constants for hardware
  values, and useful Serial logs (never log tokens or passwords).
- App: `dart format .` and keep `flutter analyze` clean.
- User-facing text: write the product name as **Darna** (capital D).

## License

By contributing, you agree that your contributions are licensed under the
project's [MIT License](LICENSE).
