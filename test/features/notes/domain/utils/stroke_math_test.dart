import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/features/notes/domain/utils/stroke_math.dart';

void main() {
  // Shared image dimensions (4000 × 3000 — simulates a 12 MP photo).
  const imageSize = StrokeSize(4000, 3000);

  group('normalizePoint', () {
    test('center of image normalizes to (0.5, 0.5)', () {
      final norm = normalizePoint(const StrokePoint(2000, 1500), imageSize);
      expect(norm.x, closeTo(0.5, 1e-10));
      expect(norm.y, closeTo(0.5, 1e-10));
    });

    test('top-left corner normalizes to (0, 0)', () {
      final norm = normalizePoint(const StrokePoint(0, 0), imageSize);
      expect(norm.x, 0.0);
      expect(norm.y, 0.0);
    });

    test('bottom-right corner normalizes to (1, 1)', () {
      final norm = normalizePoint(const StrokePoint(4000, 3000), imageSize);
      expect(norm.x, 1.0);
      expect(norm.y, 1.0);
    });

    test('out-of-bounds point is clamped to [0, 1]', () {
      final norm = normalizePoint(const StrokePoint(-100, 5000), imageSize);
      expect(norm.x, 0.0);
      expect(norm.y, 1.0);
    });

    test('zero imageSize returns (0, 0) — division-by-zero guard', () {
      final norm = normalizePoint(const StrokePoint(200, 150), const StrokeSize(0, 0));
      expect(norm.x, 0.0);
      expect(norm.y, 0.0);
    });
  });

  group('denormalizePoint', () {
    // Screen scenario 1: portrait phone (400 × 300)
    const displayPortrait = StrokeSize(400, 300);
    // Screen scenario 2: larger tablet (800 × 600)
    const displayTablet = StrokeSize(800, 600);
    // Screen scenario 3: landscape orientation (300 × 400)
    const displayLandscape = StrokeSize(300, 400);

    test('(0.5, 0.5) → center of portrait display', () {
      final px = denormalizePoint(const StrokePoint(0.5, 0.5), displayPortrait);
      expect(px.x, closeTo(200, 1e-10));
      expect(px.y, closeTo(150, 1e-10));
    });

    test('(0.5, 0.5) → center of tablet display', () {
      final px = denormalizePoint(const StrokePoint(0.5, 0.5), displayTablet);
      expect(px.x, closeTo(400, 1e-10));
      expect(px.y, closeTo(300, 1e-10));
    });

    test('(0.5, 0.5) → center of landscape display', () {
      final px = denormalizePoint(const StrokePoint(0.5, 0.5), displayLandscape);
      expect(px.x, closeTo(150, 1e-10));
      expect(px.y, closeTo(200, 1e-10));
    });

    test('(0, 0) → top-left corner on any display', () {
      final px = denormalizePoint(const StrokePoint(0, 0), displayTablet);
      expect(px.x, 0.0);
      expect(px.y, 0.0);
    });

    test('(1, 1) → bottom-right corner on portrait display', () {
      final px = denormalizePoint(const StrokePoint(1, 1), displayPortrait);
      expect(px.x, 400.0);
      expect(px.y, 300.0);
    });

    test('zero displayRect returns (0, 0) — division-by-zero guard', () {
      final px = denormalizePoint(const StrokePoint(0.5, 0.5), const StrokeSize(0, 0));
      expect(px.x, 0.0);
      expect(px.y, 0.0);
    });
  });

  group('round-trip accuracy', () {
    // A stroke point at 1/3 image width, 2/3 image height.
    const scenePoint = StrokePoint(4000 / 3.0, 3000 * 2.0 / 3.0);

    for (final display in [
      const StrokeSize(400, 300),  // portrait phone
      const StrokeSize(800, 600),  // tablet
      const StrokeSize(300, 400),  // landscape phone
    ]) {
      test('round-trip preserves position on ${display.width}×${display.height}', () {
        final normalized = normalizePoint(scenePoint, imageSize);
        final recovered = denormalizePoint(normalized, display);

        // Display position should be exactly 1/3 of width and 2/3 of height.
        expect(recovered.x, closeTo(display.width / 3.0, 1e-8));
        expect(recovered.y, closeTo(display.height * 2.0 / 3.0, 1e-8));
      });
    }
  });

  group('normalizeWidth / denormalizeWidth', () {
    test('normalizes 40 px pen on 4000 px image to 0.01', () {
      expect(normalizeWidth(40, 4000), closeTo(0.01, 1e-10));
    });

    test('denormalizes 0.01 on 800 px display to 8 px', () {
      expect(denormalizeWidth(0.01, 800), closeTo(8, 1e-10));
    });

    test('zero imageWidth returns 0.0 — division-by-zero guard', () {
      expect(normalizeWidth(10, 0), 0.0);
    });

    test('zero displayWidth returns 0.0 — division-by-zero guard', () {
      expect(denormalizeWidth(0.5, 0), 0.0);
    });
  });

  group('normalizePoints / denormalizePoints', () {
    test('batch normalize and denormalize are consistent', () {
      final scenePoints = [
        const StrokePoint(1000, 750),
        const StrokePoint(2000, 1500),
        const StrokePoint(3000, 2250),
      ];
      const display = StrokeSize(400, 300);

      final flat = normalizePoints(scenePoints, imageSize);
      final recovered = denormalizePoints(flat, display);

      expect(recovered.length, 3);
      expect(recovered[0].x, closeTo(100, 1e-8));
      expect(recovered[0].y, closeTo(75, 1e-8));
      expect(recovered[1].x, closeTo(200, 1e-8));
      expect(recovered[1].y, closeTo(150, 1e-8));
      expect(recovered[2].x, closeTo(300, 1e-8));
      expect(recovered[2].y, closeTo(225, 1e-8));
    });

    test('odd-length flat list silently drops trailing value', () {
      // [0.5, 0.5, 0.25] — orphan 0.25 at end
      final pts = denormalizePoints([0.5, 0.5, 0.25], const StrokeSize(400, 300));
      expect(pts.length, 1);
    });
  });

  group('simplifyPoints', () {
    test('removes points closer than threshold', () {
      final pts = [
        const StrokePoint(0, 0),
        const StrokePoint(1, 0),   // 1 px away — below 1.5 threshold, removed
        const StrokePoint(3, 0),   // 3 px from origin — kept
        const StrokePoint(3.5, 0), // 0.5 from prev kept — removed
        const StrokePoint(10, 0),  // kept
      ];
      final simplified = simplifyPoints(pts, threshold: 1.5);
      // First and last always kept; middle filtered.
      expect(simplified.first, const StrokePoint(0, 0));
      expect(simplified.last, const StrokePoint(10, 0));
      expect(simplified.length, lessThan(pts.length));
    });

    test('passes through list of 2 points unchanged', () {
      final pts = [const StrokePoint(0, 0), const StrokePoint(100, 100)];
      expect(simplifyPoints(pts), pts);
    });
  });
}
