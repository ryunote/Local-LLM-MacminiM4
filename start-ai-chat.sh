#!/bin/bash

# --- 設定 ---
BASE_DIR="/Users/ryunote/Code/llama"
UI_DATA_DIR="$BASE_DIR/history"
PORT_UI=3000

# 1. 終了処理 (Ctrl+C)
cleanup() {
    echo -e "\n\n--- システムを停止しています ---"
    docker compose down
    pkill ollama
    exit 0
}
trap cleanup SIGINT

# 2. ディレクトリ準備
mkdir -p "$UI_DATA_DIR"

# 3. SearXNG用の設定ファイルを自動生成 (環境を汚さないよう実行時に作成)
# ここで JSON 許可と limiter オフを確実に設定します
cat <<EOF > "$BASE_DIR/searxng_settings.yml"
use_default_settings: true
server:
  secret_key: "$(openssl rand -hex 16)"
  limiter: false
  image_proxy: true
search:
  formats:
    - html
    - json
EOF

# 4. Ollama 起動
if ! pgrep -x "ollama" > /dev/null; then
    echo "Ollama を起動しています..."
    export OLLAMA_KEEP_ALIVE="24h"
    nohup ollama serve > /dev/null 2>&1 &
    sleep 3
fi

# 5. Docker Compose で一括起動
echo "Dockerコンテナを起動しています..."
docker compose up -d --force-recreate

# 6. ヘルスチェック
echo "Web UIの準備が整うのを待っています..."
until curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT_UI | grep "200" > /dev/null; do
    printf "."
    sleep 2
done

echo -e "\n起動完了！ブラウザを開きます。"
open http://localhost:$PORT_UI

echo "------------------------------------------------------"
echo "システム稼働中... (停止するには Ctrl + C)"
echo "------------------------------------------------------"

while true; do sleep 1; done