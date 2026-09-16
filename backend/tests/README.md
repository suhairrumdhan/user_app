# Prescription extraction regressions

The mobile path reads PDF words with bounds and reconstructs visual rows. Image
OCR keeps ML Kit line geometry. No hospital-specific crop or drug-name allowlist
is used. Flask separates document metadata/instructions from medication evidence
before catalog matching. The policy identifier in `/health` is
`spatial-rows-evidence-v2`.

- `inputMode: document`: exact catalog names or stated strength/form produce
  medicine candidates. Other English text is retained in `uncertainText`, outside
  the medicine count and search payload, for explicit review/addition.
- `inputMode: manual` (or `/analyze-manual`): preserves unknown names entered by
  the user. Both modes use the same conservative matching/strength rules.
- Missing `inputMode` keeps legacy single-name compatibility. Deploy the backend
  and rebuild the mobile app to use the full layout-aware document path.
- Unknown candidates are not replaced by similarly spelled brands.

Run backend regressions from `backend`:

    python -X utf8 -B -m unittest discover -s tests -v

The optional real-file test uses the supplied two-medication Omnic/Ciprobay PDF.
Patient data is deliberately NOT checked into fixtures. From the Flutter root,
set `PRESCRIPTION_PDF_PATH` to the local original PDF and
`PRESCRIPTION_EXTRACTED_TEXT` to a temporary file outside the repository. Run:

    flutter test --no-pub test/prescription_pdf_file_test.dart

Then, in the same shell/environment, run backend tests. The optional
`test_supplied_pdf_pipeline.py` reads that actual mobile extraction and sends it
to Flask's local test client. It checks two source-preserved medicine identities
and zero stray instruction entries. Remove the temporary text after verification.

Pure layout tests cover shuffled stream order, split words, scaled font/page
sizes, baseline variation, separate rows/columns and duplicate layers. Document
tests cover wrapped strengths, metadata, page/region boundaries, unknown names
and manual input. This is not a guarantee for every layout or handwriting; the
Android camera/scanned-PDF OCR engine still needs real-device testing.
