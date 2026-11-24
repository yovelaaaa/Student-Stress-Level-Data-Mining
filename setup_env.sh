#!/usr/bin/env bash
# Creates a self-contained virtual environment for this project.
# No Homebrew / system packages required.
#
# On macOS, the XGBoost wheel expects the OpenMP runtime (libomp.dylib) at
# Homebrew's path. scikit-learn's wheel already bundles libomp, so we copy it
# next to libxgboost.dylib and add an @loader_path rpath, keeping everything
# inside .venv.
set -euo pipefail
cd "$(dirname "$0")"

PYTHON="${PYTHON:-python3}"
[ -d .venv ] || "$PYTHON" -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install -r requirements.txt

if [ "$(uname)" = "Darwin" ]; then
  SITE=$(.venv/bin/python -c "import sysconfig; print(sysconfig.get_paths()['purelib'])")
  XGB_LIB="$SITE/xgboost/lib/libxgboost.dylib"
  OMP_SRC="$SITE/sklearn/.dylibs/libomp.dylib"
  if ! .venv/bin/python -c "import xgboost" 2>/dev/null; then
    echo "Patching XGBoost to use scikit-learn's bundled libomp..."
    cp "$OMP_SRC" "$SITE/xgboost/lib/libomp.dylib"
    install_name_tool -id @rpath/libomp.dylib "$SITE/xgboost/lib/libomp.dylib"
    install_name_tool -add_rpath @loader_path "$XGB_LIB" 2>/dev/null || true
    # Modified binaries must be re-signed (ad-hoc) on Apple Silicon
    codesign --force --sign - "$SITE/xgboost/lib/libomp.dylib" "$XGB_LIB"
  fi
fi

.venv/bin/python -m ipykernel install --user --name student-stress --display-name "Python (student-stress)" >/dev/null
.venv/bin/python -c "import xgboost, sklearn, pandas; print('OK  xgboost', xgboost.__version__, '| sklearn', sklearn.__version__, '| pandas', pandas.__version__)"
