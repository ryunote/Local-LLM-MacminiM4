#!/bin/bash

# ベンチマーク設定
OLLAMA_URL="http://localhost:11434"
PROMPT="日本の首都はどこですか？その歴史と現在の役割について詳しく説明してください。"
REPEAT=3

# 測定対象モデル（引数で上書き可能）
if [ $# -gt 0 ]; then
    MODELS=("$@")
else
    mapfile -t MODELS < <(curl -s "$OLLAMA_URL/api/tags" | python3 -c "
import json,sys
tags=json.load(sys.stdin)
for m in tags.get('models',[]):
    print(m['name'])
")
fi

if [ ${#MODELS[@]} -eq 0 ]; then
    echo "[ERROR] Ollamaが起動していないか、モデルが1つもインストールされていません。" >&2
    echo "  起動: ollama serve" >&2
    echo "  モデル追加例: ollama pull llama3.2" >&2
    exit 1
fi

# 進捗はstderrへ（テーブル出力と混在させない）
echo "測定開始: ${#MODELS[@]}モデル × ${REPEAT}回" >&2
echo "" >&2

declare -a RESULTS

for model in "${MODELS[@]}"; do
    total=0
    min=99999
    max=0
    success=0

    for i in $(seq 1 $REPEAT); do
        echo -n "  [$i/$REPEAT] $model ..." >&2

        result=$(curl -s --max-time 120 "$OLLAMA_URL/api/generate" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$model\",\"prompt\":\"$PROMPT\",\"stream\":false}" \
            2>/dev/null \
           |python3 -c "
            import json,sys
            try:
                d=json.load(sys.stdin)
                tps=d['eval_count']/(d['eval_duration']/1e9)
                print(f'{tps:.2f}')
            except:
                print('ERROR')
        ")

        if [ "$result" = "ERROR" ]; then
            echo " FAILED" >&2
            continue
        fi

        echo " ${result} tok/s" >&2
        success=$((success + 1))
        total=$(python3 -c "print($total + $result)")
        min=$(python3 -c "print($result if $result < $min else $min)")
        max=$(python3 -c "print($result if $result > $max else $max)")
    done

    echo "" >&2

    if [ $success -eq 0 ]; then
        RESULTS+=("$(printf '%-44s %10s %10s %10s' "$model" 'FAILED' '-' '-')")
    else
        avg=$(python3 -c "print(f'{$total/$success:.2f}')")
        RESULTS+=("$(printf '%-44s %10s %10s %10s' "$model" "${avg}" "${min}" "${max}")")
    fi
done

# 全測定完了後にテーブルをまとめて出力
echo "======================================================"
echo " Ollama ベンチマーク結果"
echo " 実行日時: $(date '+%Y-%m-%d %H:%M:%S')"
echo " 試行回数: ${REPEAT}回 → 平均値"
echo "======================================================"
printf "%-44s %10s %10s %10s\n" "Model" "avg tok/s" "min tok/s" "max tok/s"
echo "------------------------------------------------------"
for row in "${RESULTS[@]}"; do
    echo "$row"
done
echo "======================================================"
