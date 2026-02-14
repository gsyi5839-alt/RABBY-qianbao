import React, { useMemo } from 'react';

/**
 * Simple QR code generator using SVG.
 * Produces a visual QR-like pattern from the data.
 * For production, replace with a proper QR library.
 */
function generateQRModules(data: string, size: number): boolean[][] {
  const modules: boolean[][] = [];
  let hash = 0;
  for (let i = 0; i < data.length; i++) {
    hash = (hash << 5) - hash + data.charCodeAt(i);
    hash |= 0;
  }

  for (let row = 0; row < size; row++) {
    modules[row] = [];
    for (let col = 0; col < size; col++) {
      if (
        (row < 7 && col < 7) ||
        (row < 7 && col >= size - 7) ||
        (row >= size - 7 && col < 7)
      ) {
        const isOuter =
          row === 0 ||
          col === 0 ||
          row === 6 ||
          col === 6 ||
          row === size - 1 ||
          col === size - 1 ||
          row === size - 7 ||
          col === size - 7;
        const isInner =
          (row >= 2 && row <= 4 && col >= 2 && col <= 4) ||
          (row >= 2 && row <= 4 && col >= size - 5 && col <= size - 3) ||
          (row >= size - 5 && row <= size - 3 && col >= 2 && col <= 4);
        modules[row][col] = isOuter || isInner;
      } else {
        const seed = hash ^ (row * 31 + col * 17);
        modules[row][col] = ((seed * 2654435761) >>> 0) % 3 !== 0;
      }
    }
  }
  return modules;
}

interface QRCodeSVGProps {
  value: string;
  size?: number;
}

export const QRCodeSVG: React.FC<QRCodeSVGProps> = ({
  value,
  size = 200,
}) => {
  const moduleCount = 33;
  const cellSize = size / moduleCount;
  const modules = useMemo(
    () => generateQRModules(value, moduleCount),
    [value]
  );

  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <rect width={size} height={size} fill="white" rx="12" />
      {modules.map((row, rowIdx) =>
        row.map((cell, colIdx) =>
          cell ? (
            <rect
              key={`${rowIdx}-${colIdx}`}
              x={colIdx * cellSize}
              y={rowIdx * cellSize}
              width={cellSize}
              height={cellSize}
              fill="#1A1A2E"
              rx={cellSize * 0.15}
            />
          ) : null
        )
      )}
    </svg>
  );
};
