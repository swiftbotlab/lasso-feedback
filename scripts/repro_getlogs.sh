#!/bin/bash
# Reproduce the eth_getLogs range refusal. Needs LASSO_RPC_URL (the rpc_url from POST /api/v1/keys); prints no secrets.
# Compares Lasso public/premium with base-rpc.publicnode.com for the same contract and block range.
set -euo pipefail
: "${LASSO_RPC_URL:?set LASSO_RPC_URL}"
BASE_URL="${LASSO_RPC_URL%/profile/*}/profile"
ADDR=0x5555Fa783936C260f77385b4E153B9725feF1719
rpc() { curl -s -m 60 "$1" -H 'content-type: application/json' -d "$2"; }
HEAD=$(rpc https://base-rpc.publicnode.com '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' | python3 -c 'import json,sys; print(int(json.load(sys.stdin)["result"],16))')
for SPAN in 100 500 2000 50000; do
  Q=$(printf '{"jsonrpc":"2.0","id":2,"method":"eth_getLogs","params":[{"address":"%s","fromBlock":"0x%x","toBlock":"0x%x"}]}' $ADDR $((HEAD-SPAN)) $HEAD)
  for P in public premium; do
    printf '%-7s span %-6s ' $P $SPAN
    rpc "$BASE_URL/$P/base?include_meta=body" "$Q" | python3 -c 'import json,sys; d=json.load(sys.stdin); m=d.get("lasso_meta",{}); print(("%d logs" % len(d["result"])) if "result" in d else d["error"].get("data",{}).get("code"), "| candidates", m.get("candidate_providers"), "| request_id", m.get("request_id"))'
  done
  printf 'direct  span %-6s ' $SPAN; rpc https://base-rpc.publicnode.com "$Q" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(("%d logs" % len(d["result"])) if "result" in d else d.get("error"))'
done
