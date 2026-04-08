#!/bin/bash

# --- 設定 ---
UI_DATA_DIR="/Users/ryunote/Code/llama/history"  # UIのデータ保存ディレクトリ
PORT_UI=3000

# 1. UI用のデータ保存ディレクトリ作成
mkdir -p "$UI_DATA_DIR"

# 2. Ollama (バックエンド) の起動
# すでに起動している場合は何もしない
if ! pgrep -x "ollama" > /dev/null; then
    echo "Ollama を起動しています..."
    # バックグラウンドで起動
    nohup ollama serve > /dev/null 2>&1 &
    sleep 2
fi

# 3. Open WebUI (フロントエンド) の起動
echo "Dockerコンテナを起動中..."
docker run -d \
    -p $PORT_UI:8080 \
    --add-host=host.docker.internal:host-gateway \
    -v "$PWD/${UI_DATA_DIR}:/app/backend/data" \
    -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
    --name open-webui \
    --restart always \
    ghcr.io/open-webui/open-webui:main > /dev/null 2>&1 || docker start open-webui > /dev/null

# 4. ブラウザを開く
echo "準備完了。ブラウザを起動します..."
sleep 3
open http://localhost:$PORT_UI

echo "------------------------------------------------------"
echo "【使い方】"
echo "1. ブラウザでモデル名(llama3等)を検索してダウンロードできます"
echo "2. ダウンロード後は、上部のセレクトボックスで即座に切り替え可能です"
echo "------------------------------------------------------"