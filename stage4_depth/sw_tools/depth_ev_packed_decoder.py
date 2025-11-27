import pandas as pd

df = pd.read_csv("depth_stage4.csv")

# Drop the radix row
df = df[df["Sample in Buffer"] != "Radix - UNSIGNED"].copy()

def decode_depth(depth_hex: str):
    d = int(depth_hex, 16)
    shifted = d >> 8  # drop the top 8 header bits

    update_id = (shifted >> 64) & ((1 << 64) - 1)
    price_fp  = (shifted >> 32) & ((1 << 32) - 1)
    qty_fp    = shifted & ((1 << 32) - 1)
    return update_id, price_fp, qty_fp

# Sanity-check against the other ILA probes for first few samples
for i in range(1, 6):
    row = df.iloc[i]
    u, p, q = decode_depth(row["u_core/depth_ev_packed[127:0]"])
    print(
        i,
        hex(u), hex(p), hex(q),
        " | ILA:",
        row["u_core/update_id[63:0]"],
        row["u_core/price_f32[31:0]"],
        row["u_core/qty_f32[31:0]"],
    )
