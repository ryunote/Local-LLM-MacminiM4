#!/bin/bash

# --- 設定 ---
BASE_DIR="/Users/ryunote/Code/llama"
UI_DATA_DIR="$BASE_DIR/history"
IMAGES_DIR="$BASE_DIR/images"
PORT_UI=3000

# 1. 終了処理 (Ctrl+C)
cleanup() {
    echo -e "\n\n--- システムを停止しています ---"
    docker compose down
    pkill -f "ollama serve"
    pkill -f "ComfyUI/main.py"
    exit 0
}
trap cleanup SIGINT

# 2. ディレクトリ準備
mkdir -p "$UI_DATA_DIR"
mkdir -p "$IMAGES_DIR"

# 3. SearXNG用の設定ファイルを自動生成
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
if ! pgrep -f "ollama serve" > /dev/null; then
    echo "Ollama を起動しています..."
    export OLLAMA_KEEP_ALIVE="24h"
    nohup ollama serve > /dev/null 2>&1 &
    sleep 3
fi

# 5. ComfyUI 起動
if ! pgrep -f "ComfyUI/main.py" > /dev/null; then
    echo "ComfyUI (画像生成) を起動しています..."
    # 仮想環境を有効化してバックグラウンド実行
    source "$BASE_DIR/ComfyUI/venv/bin/activate"
    # 修正後（--listen 引数を追加）
    nohup python "$BASE_DIR/ComfyUI/main.py" --listen 0.0.0.0 > /dev/null 2>&1 &
    # deactivate はサブシェル内なので不要だが一応
    sleep 5
fi

# 6. Docker Compose で一括起動
echo "Dockerコンテナを起動しています..."
docker compose up -d --force-recreate

# 7. ヘルスチェック (修正ポイント: より確実にcurlを実行)
echo "Web UIの準備が整うのを待っています..."
MAX_RETRIES=30
COUNT=0
while [ $COUNT -lt $MAX_RETRIES ]; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT_UI)
    if [ "$STATUS" == "200" ]; then
        break
    fi
    printf "."
    sleep 2
    COUNT=$((COUNT + 1))
done

echo -e "\n起動完了！ブラウザを開きます。"
open "http://localhost:$PORT_UI"

echo "------------------------------------------------------"
echo "システム稼働中... (停止するには Ctrl + C)"
echo "------------------------------------------------------"

# プロセスを維持
while true; do sleep 1; done