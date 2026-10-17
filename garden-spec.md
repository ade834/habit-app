# Garden Spec — 等级驱动的程序化花园（SwiftUI）

> 怎么用这个文件：把下面的全文复制给你的编码 AI（或拖进项目里当说明）。
> 它是自包含的——一份施工说明 + 一张数据表，不依赖任何外部文件、图片或代码库。
> Part 1 是要它做什么（英文写，编码 AI 读英文规格更稳），Part 2 是它要读的配方数据。
>
> 一句话概括：数据库只给「身份 + 品种 + 等级 + 位置」，花的样子全部在设备上现算。

---

## Part 1 — 给 AI 的施工说明

### Role
You are a senior iOS engineer specialising in generative vector graphics and
SwiftUI. You write tight, testable, well-separated Swift. Build the system below
as a self-contained module that drops into an existing SwiftUI app.

### What you are building
A garden that shows several flowers at the same time, each one independent.
Every flower is generated procedurally in vector form — there are no image assets
and the backend never sends geometry or colours. Each flower carries its own
integer level, and that level decides which life stage it is rendered in:

```
3  blooming    2  budding     1  sprouting     0  seeded
-1 wilting    -2  faded      -3  gone
```

At any moment the garden may hold a mix — one budding, one blooming, two seeded,
two wilting, one faded — and every one of them must be rendered correctly and
independently. There is no global stage for the garden.

There are 12 flower species in three rarity tiers, and the tier decides how
elaborate the rendering may be:

- **Tier S — 华丽 (5)**: opulent. Multi-layered petals that unfurl layer by layer,
glowing petal edges, heavy particle work, secondary blooms, they pull the most
visitors.
- **Tier A — 特别 (4)**: one strong signature trait each, instantly recognisable.
- **Tier B — 自然 (3)**: relaxed and casual, low cost, and the species that may
grow companion foliage — grass blades, small vines, twigs.

The user can drag flowers around and compose them into bouquets, and the
resulting positions are written back to the database.

### The one rule everything rests on
The database supplies identity, species, a level and a position. It never
supplies colours, petal counts or curves.

```swift
struct BloomRecord: Identifiable, Sendable {
  let id: String            // stable — the seed for everything, and the diff key
  let species: String       // a key into the recipe table, e.g. "peony"
  let level: Int            // -3 … 3
  var position: CGPoint     // normalised 0…1 inside the stage area; the STEM BASE,
                            // not the flower head
}
```

All geometry is computed on-device. The payload stays tiny, the data can change
freely, and a given record always looks like itself.

---

### 1. The recipe table
Read Part 2 of this document. One row per species: archetype, petal count
range, petal layer count, petal shape, centre treatment, palette, scale, signature
trait, companion foliage. Treat it as data, not code — adding a 13th species
means one new row plus, at most, one new archetype, never a new branch inside the
renderer. Decode it from JSON into a named Swift struct with a validation step
that fails loudly on an unknown archetype or an out-of-range parameter.

### 2. Deterministic randomness
`seed = fnv1a(record.id)` (64-bit). Implement a seeded PRNG (splitmix64 or
xorshift) plus a hash-mix helper.

Never call `Double.random` in the render path. Petal count, curve, lean,
palette offset, per-petal jitter and animation phase all come from the seed plus
a stable sub-index, e.g. `prng(seed &+ 7)`.
The same seed must yield bit-identical geometry on every launch and device.
Sample the recipe's ranges once per record and cache them; a refresh must
never re-randomise an existing flower.

### 3. Levels, and how a flower moves between them

| level | stage | stem height | what it looks like |
| :--- | :--- | :--- | :--- |
| **3** | 开花 blooming | 100% | full bloom; tier S unfurls layer by layer with glowing edges and a particle burst; visitors gather |
| **2** | 花苞 budding | 70% | bud casing wrapped and swelling, breathing pulse, head closed |
| **1** | 发芽 sprouting | 30% | two seed leaves pushed out of cracked soil, faint wobble |
| **0** | 埋种 seeded | 6% | a small mound of disturbed soil and a barely visible shoot tip; almost still |
| **-1** | 枯萎 wilting | 88% | desaturated 45%, head drooping 28°, 1–2 petals fall |
| **-2** | 凋谢 faded | 70% | petals gone, only calyx and a dry stem drooping 55°, particles disperse |
| **-3** | 消失 gone | 0% | no flower drawn at all; keep the slot's position in the database so it can regrow in place |

**Interpolation**. Keep a `renderLevel: Double` that critically-damped-springs
toward `targetLevel: Int` over 0.6–1.2 s, then derive every visual parameter by
piecewise interpolation across the table above. Because the levels are ordered,
a `1 → 3` change makes the flower visibly pass through budding on its way to full
bloom. Never swap sprites; a level change must read as the flower growing or
wilting.

**One exception — crossing the 0 / -1 boundary**. There is no physically
continuous morph from a dried faded stem into fresh seed leaves. When the target
crosses that boundary in either direction, do not interpolate geometry: dissolve
the old form into a short particle burst (~0.5 s) and grow the new form from the
soil (~0.35 s). Every other adjacent pair interpolates continuously.

**Flap protection**. Levels arrive as integers, so there are no boundary-threshold
flickers — but a level that flaps between two values will still make the spring
chase. Ignore a new target that arrives within 400 ms of the previous one and
starts the spring from the current render value, so a rapid `2 → 3 → 2` is absorbed
rather than jittered.

### 4. Geometry
Everything is `SwiftUI.Path` / `Shape`; nothing rasterised inside the bloom, so it
stays crisp at any scale.

- **Stem** — cubic Bézier from the stem base to the tip; control points from a
seeded lean and curve, line width proportional to stem height. It loses
stiffness as the flower wilts, and the tip is what droops.
- **Sprigs / companion foliage** — 1–2 leaf shapes at seeded fractions along the
stem. Tier B species may additionally spawn grass, vine or twig sprites (§8).
- **Head** — the archetype from the recipe: `spiral-rose`, `radial-multi`,
`asymmetric-special`, `orb-seedhead`, `simple-bowl`, `disc-ray`,
`bell-raceme`, `cluster-wild`. A radial bloom is n rotations of one petal
path around the tip; a spiral bloom offsets each layer's rotation by the golden
angle. Apply seeded per-petal jitter in length, width and rotation. At level 2
wrap the head in the bud casing; at −1 and −2 progressively remove petals in the
seeded drop order.
- **Colour** — base hue from the species palette; derive tints, the shadow side
and the wilted tone with lighten/darken/saturate helpers on that hue. Never
hard-code a per-flower colour, and drive desaturation from the interpolated
stage value rather than from a second palette.

### 5. Tier expression budgets

| tier | species | petal layers | petals / bloom | particles | extras | cache |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **S 华丽** | 5 | 4–6 | 60–140 | 60–120 on opening + 12–20 persistent motes | layers unfurl in sequence (outer first), glowing petal edges, opening shockwave, secondary side blooms, strongest attraction | one cached bitmap per layer |
| **A 特别** | 4 | 2–3 | 24–60 | 20–40 on opening | exactly one signature trait, done well | one cached bitmap per bloom |
| **B 自然** | 3 | 1–2 | 8–20 | 6–12 (pollen) | loose sway, optional companion foliage, occasional extra sprouts nearby | one cached bitmap per bloom |

The flourishes fire when a flower arrives at level 3. Tier S must not cost more
than ~3× a tier B bloom at rest; at rest every tier draws from cached bitmaps.

### 6. Layout and z-order
Because flowers sit at different levels at the same time, heights differ a lot — a
level 0 mound beside a level 3 bloom. Handle it deliberately:

- Each flower roots at its stored position, normalised 0…1 within the stage
area (x from the left, y measured from the bottom, so a device or orientation
change never moves anything).
- Flowers with no stored position get a seeded slot spread across the area, so the
garden is never a single pile.
- Draw furthest-to-nearest: sort by the stem base y (lower on screen draws later),
and break ties by most recently touched. A newly planted or dragged flower comes
to the front while it settles.
- Keep level 0 and −3 slots lightly grabbable (a small invisible hit area around
the soil mark) so a flower can be repositioned even while it is dormant — that
position is what its next sprout will use.

### 7. Drag, composition, and writing back
- **Plant** — drag from a bottom tray onto the stage; show a ghost preview that
follows the finger; on release insert and grow the sprout in.
- **Pick and move** — hit-test by distance to the stem's tip, not its bounding
box, within ~48 pt. Drag to reposition.
- **Compose** — dropping a stem onto another snaps them into a cluster: bases
spread on a small ellipse, the tallest takes the centre, the rest lean outward
and stagger in height. A cluster is a group, not a merge.
- **Cut** — drag a stem below the vessel rim; it fades out and is removed.
- **Gust** — tap empty space to blow wind from that point.
- **Burst** — double-tap a bloom: particle burst, petals snap back, a nearby
visitor startles.
- A fast drag (>120 pt/s) contributes wind to the whole garden.

**Writing positions back. On drag release:**
- Update locally first (optimistic) — the flower must never snap back while the
network is in flight.
- Debounce ~600 ms and coalesce: several quick moves write once.
- Send only the position: `PATCH /blooms/:id { "position": { "x": 0.42, "y": 0.68 } }`.
- Never PUT the whole record. The level is pushed by the backend and will
often be newer than your local copy; a whole-record write would silently revert
someone's flower to an old stage. This is the single most likely bug in this
feature — patch the one field.
- On failure, keep the local value and retry with exponential backoff from a small
local queue, replaying in order after a reconnect. Do not show a modal error —
the interaction must stay invisible when it works and stay usable when it
doesn't.
- On conflict (the server returns a different position with a newer timestamp —
a second device), ease the flower to the server's position over ~0.3 s. Never
teleport it.
- `-3` gone flowers keep their stored position untouched; when the level rises
again they regrow exactly where they were.

### 8. Visitors and companion foliage
Per-flower attraction = `tierWeight × levelWeight`, with `tierWeight` S 3.0 /
A 2.0 / B 1.0 and `levelWeight` 3 → 1.0, 2 → 0.3, 1 → 0, 0 → 0, −1 → 0.15,
−2 → 0, −3 → 0.

| visitor | motion | notes |
| :--- | :--- | :--- |
| **bee** | short linear dashes with pauses, figure-eight hover before landing | any tier at level 3; up to 2 per flower, 3 on tier S |
| **butterfly** | Bézier arcs with a sinusoidal bob, 2 wing beats | prefers tier S and A; up to 2 per flower |
| **firefly** | slow drift, pulsing glow, only in a dark palette or after dusk | rare; only attracted by a tier S bloom at level 3 |

- On-screen cap 5 visitors total; while any flower has attraction > 0, attempt a
spawn every 4–12 s, weighted by attraction.
- Approach → hover/land on a bloom tip → rest 2–6 s → leave. A drag starting
within 120 pt startles them: flee outward fast, re-arm that visitor after 3 s.
- **Companion foliage** — seeded grass, vines and twigs around tier B flowers
(cap ~6 on screen). Purely decorative, tied to no record, swaying with the same
wind. They also appear while a flower is still dormant, which is what makes a
half-empty garden look alive.

### 9. Live updates
The backend pushes levels; the user writes positions. Merge the two per field:
- `new id` → insert at level 1 and grow in
- `vanished id` → drive it to −2, then −3 (never pop it out)
- `level changed` → move the target level and let the spring do the rest
- `position changed remotely` → ease to it (§7)
- A refresh must never re-seed, re-order or flicker existing flowers, and must
never clobber an in-flight local position.

### 10. Performance budget
- 60 fps on a mid-range iPhone with up to 12 flowers on screen, including a tier S
bloom mid-unfurl, in mixed stages.
- Cap the render scale at 2×; stay DPR-aware.
- Cache each bloom layer as an offscreen bitmap (`ImageRenderer` / `CGImage`)
and re-cache only when that layer's parameters change. Never rebuild petal paths
per frame — transform cached layers instead.
- Pre-render the background and the vessel once.
- One display-linked ticker (`TimelineView(.animation)` or a `CADisplayLink`)
drives every stem, visitor and foliage sprite.
- Keep a rolling average of frame time; drop the render scale once if it slips.

### 11. Acceptance criteria
1. A single flower moved 0 → 1 → 2 → 3 → 2 → −1 → −2 → −3 animates through every
stage continuously, with the 0 / −1 crossing handled as a dissolve, and never
jumps.
2. Seven flowers at levels 2, 3, 0, 1, 2, 0, 0 all render correctly side by side,
each independent, with sensible z-order and no overlap chaos.
3. All 12 species are recognisably distinct, and a tier S bloom is visibly far more
elaborate than a tier B one.
4. The same record produces the same flower on every launch and device; a refresh
changes only what actually changed.
5. Plant, drag, compose, cut, gust and burst all work by touch alone with immediate
physical feedback.
6. A dragged position survives a relaunch and appears on a second device at the
same relative spot; a level push that lands mid-drag is not lost or reverted.
7. Adding a 13th species requires one new recipe row and no renderer changes.
8. No image assets, no server geometry, 60 fps at 12 mixed-stage flowers.

### Deliverable
- File layout for the module and where it hooks into the host view.
- The recipe table decoded from JSON with loud validation.
- Pure functions (`seed`, `prng`, `sampleRecipe`, `stage(for: level)`,
`parameters(level:)`) separated from the view layer and unit-tested.
- A short note on swapping the data source (local database ↔ remote API).

---

## Part 2 — 配方数据

列名是英文标识符（直接做 Swift 字段名），说明是中文。

### 1. 12 种花 (species)
稀有度三档决定表现力预算：S 华丽（重瓣、逐层绽放、发光边缘、大量粒子）、
A 特别（一件招牌特征，辨识度极高）、B 自然（松弛随性，可长伴生植物）。

| id | 中文 | tier | archetype | petalCount | petalLayers | petalShape | center | palette | scale | signature | foliage |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **peony** | 牡丹 | S | spiral-rose | 90–140 | 5–6 | broad-ruffled | 金蕊密簇 dense-stamen | 胭脂红 / 蜜桃粉 / 象牙白 | 1.15 | 逐层螺旋绽放，外层先开内层后开 | 大叶 |
| **rose** | 月季 | S | spiral-rose | 60–90 | 4–5 | cupped-teardrop | 紧螺旋眼 spiral-eye | 深红 / 玫粉 / 奶白 | 1.00 | 瓣缘发光，开花瞬间有一圈冲击波 | 复叶 |
| **dahlia** | 大丽花 | S | radial-multi | 100–140 | 5–6 | pointed-quill | 极小盘 tiny-disc | 酒红 / 亮橙 / 紫 | 1.10 | 几何级对称，左右近乎镜像 | 无 |
| **orchid** | 兰花 | S | asymmetric-special | 5 主瓣 + 1 唇瓣 | 2 | wing-and-lip | 发光花心 glowing-core | 淡紫 / 白 / 青 | 0.95 | 不对称结构，花脉发光，随微风轻转 | 气生根、细藤 |
| **lotus** | 莲花 | S | radial-multi | 40–70 | 4 | pointed-long | 莲蓬 + 金粉 pod-with-dust | 粉 / 白 | 1.20 | 双层放射、金粉持续飘落、水面倒影 | 圆叶 |
| **iris** | 鸢尾 | A | asymmetric-special | 3 垂瓣 + 3 立瓣 | 1 | drooping-standard | 金黄脊 gold-crest | 蓝紫渐变 | 1.00 | 三垂三立，紫色沿花瓣流动 | 剑叶 |
| **dandelion** | 蒲公英 | A | orb-seedhead | ~60 根绒丝 | 1 | filament-tuft | 无 | 银白 | 0.85 | 绒球遇风整体飞散——等级变化时最有戏 | 齿状叶 |
| **poppy** | 虞美人 | A | simple-bowl | 4–6 | 1 | paper-thin-ruffled | 深色花心 + 花蕊环 | 猩红 / 橙 | 1.00 | 纸薄花瓣持续微颤，风大时整朵晃 | 纤细毛茎 |
| **sunflower** | 向日葵 | A | disc-ray | 16–24 舌瓣 | 1 | long-oblong | 斐波那契籽盘 fibonacci-disc | 金黄 + 深褐心 | 1.25 | 花心按斐波那契螺旋排列，枯萎时整盘低垂 | 大叶 |
| **daisy** | 雏菊 | B | simple-bowl | 12–20 | 1 | slim-round | 黄色小圆 yellow-dot | 白 + 黄 | 0.70 | 松弛自然的单层细瓣，轻摇 | 细草茎 |
| **lily-of-valley** | 铃兰 | B | bell-raceme | 6–10 铃 | 1 | dangling-bell | 无 | 奶白 | 0.65 | 一茎多铃，自上而下依次垂开 | 宽叶 |
| **clover** | 三叶草野花草 | B | cluster-wild | 5–9 小花 | 1 | tiny-round | 淡黄 pale-yellow | 白 / 淡粉 | 0.55 | 簇生小碎花，常与草叶藤蔓混生 | 草叶 / 藤蔓 / 小枝 |

#### 编码样式 JSON
```json
[
  { "id": "peony", "nameZh": "牡丹", "tier": "S", "archetype": "spiral-rose",
    "petalCount": [90, 140], "petalLayers": [5, 6], "petalShape": "broad-ruffled",
    "center": "dense-stamen", "palette": ["#C6235B", "#F3A0A8", "#F6EEDC"],
    "scale": 1.15, "signature": "layerSequence", "foliage": "broad-leaf" },
  { "id": "rose", "nameZh": "月季", "tier": "S", "archetype": "spiral-rose",
    "petalCount": [60, 90], "petalLayers": [4, 5], "petalShape": "cupped-teardrop",
    "center": "spiral-eye", "palette": ["#8E1B2E", "#D8546E", "#F7EFE4"],
    "scale": 1.0, "signature": "glowEdge", "foliage": "compound-leaf" },
  { "id": "dahlia", "nameZh": "大丽花", "tier": "S", "archetype": "radial-multi",
    "petalCount": [100, 140], "petalLayers": [5, 6], "petalShape": "pointed-quill",
    "center": "tiny-disc", "palette": ["#7A0026", "#FF6B2B", "#6A1B9A"],
    "scale": 1.10, "signature": "geometricSymmetry", "foliage": "none" },
  { "id": "orchid", "nameZh": "兰花", "tier": "S", "archetype": "asymmetric-special",
    "petalCount": [6, 6], "petalLayers": [2, 2], "petalShape": "wing-and-lip",
    "center": "glowing-core", "palette": ["#BA68C8", "#F3E5F5", "#80CBC4"],
    "scale": 0.95, "signature": "glowingVeins", "foliage": "aerial-roots" },
  { "id": "lotus", "nameZh": "莲花", "tier": "S", "archetype": "radial-multi",
    "petalCount": [40, 70], "petalLayers": [4, 4], "petalShape": "pointed-long",
    "center": "pod-with-dust", "palette": ["#F06292", "#FFFFFF", "#FFE082"],
    "scale": 1.20, "signature": "goldDustCascade", "foliage": "round-leaf" },
  { "id": "iris", "nameZh": "鸢尾", "tier": "A", "archetype": "asymmetric-special",
    "petalCount": [6, 6], "petalLayers": [1, 1], "petalShape": "drooping-standard",
    "center": "gold-crest", "palette": ["#3949AB", "#8E24AA", "#FFD54F"],
    "scale": 1.00, "signature": "gradientFlow", "foliage": "sword-leaf" },
  { "id": "dandelion", "nameZh": "蒲公英", "tier": "A", "archetype": "orb-seedhead",
    "petalCount": [55, 65], "petalLayers": [1, 1], "petalShape": "filament-tuft",
    "center": "none", "palette": ["#ECEFF1", "#CFD8DC", "#B0BEC5"],
    "scale": 0.85, "signature": "filamentDisperse", "foliage": "toothed-leaf" },
  { "id": "poppy", "nameZh": "虞美人", "tier": "A", "archetype": "simple-bowl",
    "petalCount": [4, 6], "petalLayers": [1, 1], "petalShape": "paper-thin-ruffled",
    "center": "dark-stamen-ring", "palette": ["#D32F2F", "#FF5722", "#212121"],
    "scale": 1.00, "signature": "paperTremble", "foliage": "hairy-stem" },
  { "id": "sunflower", "nameZh": "向日葵", "tier": "A", "archetype": "disc-ray",
    "petalCount": [16, 24], "petalLayers": [1, 1], "petalShape": "long-oblong",
    "center": "fibonacci-disc", "palette": ["#FFB300", "#5D4037", "#FFA000"],
    "scale": 1.25, "signature": "fibonacciCenter", "foliage": "broad-leaf" },
  { "id": "daisy", "nameZh": "雏菊", "tier": "B", "archetype": "simple-bowl",
    "petalCount": [12, 20], "petalLayers": [1, 1], "petalShape": "slim-round",
    "center": "yellow-dot", "palette": ["#FFFFFF", "#F4D262"],
    "scale": 0.70, "signature": "looseSway", "foliage": "thin-stem" },
  { "id": "lily-of-valley", "nameZh": "铃兰", "tier": "B", "archetype": "bell-raceme",
    "petalCount": [6, 10], "petalLayers": [1, 1], "petalShape": "dangling-bell",
    "center": "none", "palette": ["#FAFAFA", "#E0E0E0", "#C8E6C9"],
    "scale": 0.65, "signature": "cascadingBells", "foliage": "broad-leaf" },
  { "id": "clover", "nameZh": "三叶草野花草", "tier": "B", "archetype": "cluster-wild",
    "petalCount": [5, 9], "petalLayers": [1, 1], "petalShape": "tiny-round",
    "center": "pale-yellow", "palette": ["#FFFFFF", "#F8BBD0", "#FFF9C4"],
    "scale": 0.55, "signature": "wildCluster", "foliage": "clover-twigs" }
]
```

每条记录同时带 level 与 position：
```json
{ "id": "b_7f3a", "species": "rose", "level": 3,
  "position": { "x": 0.42, "y": 0.68 } }
```

---

### 2. 七个等级 (level)
等级是整数，不是连续数值。数值上升不等于走向凋谢——3 是开花，往负方向才是衰败。
所以「数值变了」有两类完全不同的走法：0→3 是生长，0→-3 是衰败。

| level | 名称 | 茎高 | 花朵 | 褪色 | 垂头 | 掉瓣 | 粒子 | 画面 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **3** | 开花 blooming | 100% | 100% | 0 | 0° | 0 | S 60–120 / A 20–40 / B 6–12 | 全盛。S 档分层绽放、瓣缘发光、冲击波；访客聚集 |
| **2** | 花苞 budding | 70% | 花苞包裹 | 0.05 | 0° | 0 | 呼吸微光 2–4 | 苞衣包紧、缓缓鼓胀，头部闭合 |
| **1** | 发芽 sprouting | 30% | 两片真叶 | 0 | 0° | 0 | 土屑 6 | 土面裂开，真叶顶出，轻微晃 |
| **0** | 埋种 seeded | 6% | — | 0 | 0° | 0 | 0 | 只有一小撮松土和几乎看不见的芽尖，近乎静止 |
| **-1** | 枯萎 wilting | 88% | 78% | 0.45 | 28° | 1–2 片 | 8 | 褪色、垂头、掉瓣 |
| **-2** | 凋谢 faded | 70% | 25%（只剩花萼） | 0.80 | 55° | 余瓣落尽 | 16 | 干茎垂着，粒子散去 |
| **-3** | 消失 gone | — | — | — | — | — | — | 不画花，只保留花位痕迹与数据库里的位置，等级回升时原地复活 |

同屏多朵各自独立：可能出现 2、3、0、1、2、0、0 这样的七种状态并存。

#### 等级之间怎么过渡（这一节最要紧）：
- 所有相邻等级都连续插值，不许可切换素材。0→3 的过程中会依次经过发芽和花苞，用户看到的是它一路长起来。
- **只有跨越 0 与 -1 之间不做几何插值**：从干枯的残茎连续变形到嫩芽是违背物理的。这个跨越要用「旧形态溶解成粒子（约 0.5s）+ 新形态从土里长出（约 0.35s）」交接。
- 弹簧追值 0.6–1.2s，距离越大给的时间越长，别让 -2→3 的「回春」显得瞬移。
- 400ms 内的目标变更直接吸收掉（从当前渲染值重新起弹），避免 2→3→2 来回抖动。
- 等级是整数，所以不存在阈值抖动——不需要滞回，只需要上面这条防抖。

#### 展开节奏按档位分：
| tier | 展开方式 | 时长 |
| :--- | :--- | :--- |
| **S** | 分层：外层 t 0→0.55，内层 0.35→1.0，层与层错开 | 0.9–1.4 s |
| **A** | 整体 t 0→1，带一次回弹过冲 | 0.5–0.7 s |
| **B** | 整体 t 0→1，轻快 | 0.3–0.45 s |

---

### 3. 访客与伴生植物
每朵花的吸引值 `attraction = tierWeight × levelWeight`：
- `tierWeight`: S 3.0 / A 2.0 / B 1.0
- `levelWeight`: 3 → 1.0、2 → 0.3、1 → 0、0 → 0、-1 → 0.15、-2 → 0、-3 → 0

| 访客 | 运动 | 出现规则 |
| :--- | :--- | :--- |
| **蜜蜂 bee** | 短促直线冲刺 + 停顿，停落前画 8 字悬停 | 任何档位处于等级 3；每朵上限 2，S 档 3 |
| **蝴蝶 butterfly** | 贝塞尔弧线 + 正弦上下起伏，双翅各 2 帧 | 偏好 S / A 档；每朵上限 2 |
| **萤火虫 firefly** | 缓慢漂移，光晕脉动 | 稀有；只在暗色调或夜间模式被 S 档的等级 3 吸引 |

- 同屏总数上限 5 只；只要有任何花 attraction > 0，每 4–12 s 尝试生成一次，按吸引值加权选目标。
- 行为链：飞入 → 悬停/停落在花瓣尖端 → 停留 2–6 s → 离开。
- 手指在 120 pt 内开始拖拽会惊飞：快速向外逃离，3 s 后重新参与生成。
- **伴生植物**：B 档花周围概率生成草叶、藤蔓、小枝（同屏上限约 6），纯装饰、不绑记录、跟随同一阵风。它们在花还没发芽时也照常存在——这是让半空的花园看起来仍然活着的原因。

---

### 4. 示例一：一朵 S 档月季，等级从 0 走到 3 再衰到 -3
- **0 埋种**：一小撮松土，几乎看不见的芽尖
- **0 → 1**：两片真叶顶出，土面裂开，轻晃 0.4s
- **1 → 2**：茎抽到 70%，真叶定型，苞衣把花头包起来，开始细密的呼吸脉动
- **2 → 3**：5 层花瓣在 1.1s 内逐层螺旋展开，瓣缘亮起，80 粒金粉迸出，一圈冲击波；4s 后 2 只蜜蜂飞入
- **3 → 2**：花瓣按种子顺序收回苞衣，金粉回落，蜜蜂离开
- **2 → 1**：茎缩短到 30%，只剩两片真叶
- **1 → 0**：形态溶解成一小蓬土屑，新芽尖从土里冒出（跨界交接，不做几何插值）
- **0 → -1**：直接从土里长出一株枯萎的干茎：褪色 45%，垂头 28°，掉 2 片瓣。同样是跨界交接
- **-1 → -2**：余瓣落尽，花萼垂到 55°，粒子散去
- **-2 → -3**：土壤痕迹淡去，花位保留，位置仍存在数据库里

---

### 5. 示例二：七朵花同时存在
数据库给出七条记录，等级分别是 2、3、0、1、2、0、0：
- 两朵在花苞、一朵盛开、一朵发芽、三个花位是土堆。
- 七朵各自独立推进，谁也不影响谁；同时出现两个等级 2 时，它们的外观不一样（等级相同、但 id 种子不同，所以花瓣数、倾角、配色深浅各不相同）。
- 绘序按茎基 y 从小到大：靠下的画在后面、靠上的画在前面；刚刚拖动的处于最前。
- 等级 0 的花位虽然只有一小撮土，仍留了一个小的可点区域——用户现在把它拖到哪儿，它将来的芽就从哪儿冒出来。

---

### 6. 示例三：拖拽写回
把月季从 `(0.42, 0.68)` 拖到 `(0.61, 0.55)`：
- 松手瞬间先在本地落位（乐观更新），画面不回弹。
- 600ms 内不再有其他移动，合并成一次请求：`PATCH /blooms/b_7f3a { "position": { "x": 0.61, "y": 0.55 } }`。只带 position，不带 level。
- 网络失败：保留本地位置，放进本地队列指数退避重试，重连后按顺序重放，不弹报错。
- 另一台设备同时移动了这朵花：以服务端较新的时间戳为准，用约 0.3s 补间滑过去，不瞬移。
- 坐标是相对舞台区域的 0–1 归一化值，x 从左算、y 从底算，记的是茎基位置而非花头，这样换机型、转屏、改分辨率都不会偏。

---

### 7. 示例四：新增第 13 种花
在表里加一行，比如：
```json
{ "id": "camellia", "nameZh": "山茶", "tier": "S", "archetype": "spiral-rose",
  "petalCount": [40, 60], "petalLayers": [4, 4], "petalShape": "broad-round",
  "center": "dense-stamen", "palette": ["#D81B60", "#F48FB1", "#FFF0F5"],
  "scale": 1.05, "signature": "singleBurstWaxGlow", "foliage": "thick-leaf" }
```
archetype 已存在（spiral-rose）→ 不改任何渲染代码，重启即长出山茶。
只有当新花需要一种全新结构（比如垂挂的穗状花序）时，才新增一个 archetype。
