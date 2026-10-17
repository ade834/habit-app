import SwiftUI

// MARK: - POSY 风格高级配色系统（支持相邻色、对比色与丰富花粉层次）
public struct PosyPalette: Sendable {
    public let primary: Color      // 主色调
    public let secondary: Color    // 相邻衍生色
    public let accent: Color       // 对比跳色 / 点睛色 (Rich contrast)
    public let glow: Color         // 扩散光晕底色
    public let halo: Color         // 同心涟漪环颜色
    public let stamen: Color       // 中心雄蕊/雌蕊核色彩
    public let stem: Color         // 茎秆颜色
    public let pollens: [Color]    // 多色花粉阵列 (含对比色粒子)

    public init(
        primary: Color,
        secondary: Color,
        accent: Color,
        glow: Color,
        halo: Color,
        stamen: Color,
        stem: Color = Color(red: 0.35, green: 0.55, blue: 0.38),
        pollens: [Color] = [.white, Color(red: 1.0, green: 0.85, blue: 0.6)]
    ) {
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.glow = glow
        self.halo = halo
        self.stamen = stamen
        self.stem = stem
        self.pollens = pollens
    }
}

// MARK: - 12 种植物的 POSY 艺术定义（色相环全方位差异化，拉开前四种及全部植物辨识度）
public enum PosyFloraType: String, CaseIterable, Identifiable, Sendable {
    case hawthorn       = "hawthorn"        // 1. 山楂花 Hawthorn (暖珊瑚朱红 + 金丝微光，对比青金石花粉)
    case dandelion      = "dandelion"       // 2. 蒲公英 Dandelion (晴空天青蔚蓝 + 鹅黄微絮，对比暖琥珀芯)
    case bayWreath      = "bayWreath"       // 3. 桂冠枝 Bay Wreath (薄荷翠松绿 + 珊瑚粉浆果对撞)
    case cornflower     = "cornflower"      // 4. 矢车菊 Cornflower (深邃皇家钴蓝 + 紫罗兰相邻色 + 纯白冰晶)
    case redBerries     = "redBerries"      // 5. 红浆果 Drooping Berries (暗绯石榴红 + 柠檬黄对比高光点)
    case hydrangea      = "hydrangea"       // 6. 绣球花 Hydrangea (蓝紫幻彩渐变 + 薰衣草紫 + 银白星光)
    case mimosa         = "mimosa"          // 7. 金合欢 Mimosa (日落暖金橙 + 蜜桃粉相邻色)
    case allium         = "allium"          // 8. 大花葱 Allium (神秘深邃丁香紫 + 霓虹青对比花粉)
    case lotusPod       = "lotusPod"        // 9. 莲华芯 Lotus Core (湖心青碧翡翠 + 郁金香明黄莲孔)
    case cherryBlossom  = "cherryBlossom"   // 10. 樱花霰 Cherry Aura (粉白柔樱 + 胭脂玫红内核 + 金绿微蕊)
    case cosmos         = "cosmos"          // 11. 格桑花 Cosmos (暖阳向日红紫 + 太阳金盘圆心)
    case nightJasmine   = "nightJasmine"    // 12. 夜茉莉 Night Jasmine (夜幕靛青蓝 + 珍珠白荧光星芒)

    public var id: String { rawValue }

    public var titleZh: String {
        switch self {
        case .hawthorn: return "1. 蓝金星芒"
        case .dandelion: return "2. 珊瑚伞花"
        case .bayWreath: return "3. 孔雀彩扇"
        case .cornflower: return "4. 几何风车"
        case .redBerries: return "5. 垂帘浆果"
        case .mimosa: return "6. 金琥珀阳"
        case .hydrangea: return "7. 青绒蒲公英"
        case .allium: return "8. 珊瑚青瓣"
        case .lotusPod: return "9. 金晕绯瑰"
        case .cherryBlossom: return "10. 双色几何伞"
        case .cosmos: return "11. 经纬金晕葱"
        case .nightJasmine: return "12. 极夜十二星"
        }
    }

    public var meaningZh: String {
        switch self {
        case .hawthorn: return "秩序 · 深邃钴蓝与金斑的星核 (Row 1-L)"
        case .dandelion: return "温润 · 珊瑚伞簇与微蜂的共舞 (Row 2-L)"
        case .bayWreath: return "华彩 · 极简彩虹扇面的梯阶 (Row 3-L)"
        case .cornflower: return "折射 · 棱镜分形多边形风车 (Row 4-L)"
        case .redBerries: return "垂落 · 拱桥垂帘晶润覆盆子 (Row 5-L)"
        case .mimosa: return "破晓 · 晨曦琥珀光环金阳花 (Row 6-L)"
        case .hydrangea: return "绒羽 · 青绒初散与紫红全盛 (Row 1-R)"
        case .allium: return "对撞 · 珊瑚明瓣与绿松石芯 (Row 2-R)"
        case .lotusPod: return "绚烂 · 绯瑰重瓣与太阳金晕 (Row 3-R)"
        case .cherryBlossom: return "静禅 · 澄澈双色悬挂几何伞 (Row 4-R)"
        case .cosmos: return "经纬 · 球面经纬网格金辉葱 (Row 5-R)"
        case .nightJasmine: return "极夜 · 钴蓝十二面体棱镜星 (Row 6-R)"
        }
    }

    // MARK: - 各植物物理风动特性 (质量、受风面、摇摆频率与最大倾角系数)
    public var windInertia: Double {
        switch self {
        case .hawthorn: return 1.10
        case .dandelion: return 0.85
        case .bayWreath: return 0.95
        case .cornflower: return 1.00
        case .redBerries: return 1.35
        case .mimosa: return 1.05
        case .hydrangea: return 0.75
        case .allium: return 1.00
        case .lotusPod: return 1.15
        case .cherryBlossom: return 0.90
        case .cosmos: return 1.25
        case .nightJasmine: return 1.10
        }
    }

    public var swayFrequency: Double {
        switch self {
        case .hydrangea: return 1.40
        case .dandelion, .cherryBlossom: return 1.20
        case .hawthorn, .bayWreath, .cornflower, .allium: return 1.00
        case .mimosa, .lotusPod, .nightJasmine: return 0.85
        case .redBerries, .cosmos: return 0.70
        }
    }

    // MARK: - 各植物差异化风动反馈动力学参数 (显著拉开晃动时间、弯曲幅度与回弹频率，差异达 4~6 倍)

    /// 茎秆迎风受力柔韧弯曲系数 (0.35 ~ 1.55，幅度相差 4.4 倍，明显可辨)
    public var stemFlexFactor: Double {
        switch self {
        case .cosmos:        return 1.55 // 11. 经纬金晕葱: 250pt 极长纤细高杆，风推深弯倾斜大弧 (极高柔韧)
        case .hawthorn:      return 1.45 // 1.  蓝金星芒: 270pt 挺拔最高主干，随风巨幅摇曳
        case .allium:        return 1.35 // 8.  珊瑚晶球: 245pt 细韧悬臂，如钓竿般大幅迎风弯曲
        case .cornflower:    return 1.15 // 4.  几何风车: 220pt 右侧迎风舒展，弯曲柔顺
        case .bayWreath:     return 1.05 // 3.  孔雀彩扇: 215pt 弹力枝条，中大幅度弯摆
        case .dandelion:     return 0.95 // 2.  珊瑚伞花: 195pt 轻巧伞骨，优雅微弯
        case .nightJasmine:  return 0.90 // 12. 极夜十二星: 235pt 挺拔韧枝
        case .cherryBlossom: return 0.85 // 10. 双色几何伞: 175pt 悬垂轻盈
        case .lotusPod:      return 0.65 // 9.  珊瑚霞光球: 185pt 结实稳重中柱，轻度偏摆
        case .redBerries:    return 0.50 // 5.  垂帘浆果: 160pt 木质重果枝，茎秆刚劲微弯
        case .mimosa:        return 0.85 // 6.  金琥珀阳: 140pt 矮壮短枝，抗风性强
        case .hydrangea:     return 0.35 // 7.  青绒蒲公英: 135pt 最矮最刚挺短茎，受风位移极小
        }
    }

    /// 茎秆回弹阻尼率 (1.1 ~ 4.5，决定茎秆在风停后多快静止，相差 4 倍)
    public var stemReboundSpeed: Double {
        switch self {
        case .hydrangea:     return 4.5  // 7.  青绒蒲公英: 超高阻尼，风停后 0.5s 瞬间复位静止
        case .mimosa:        return 4.0  // 6.  金琥珀阳: 0.6s 快速弹回复位
        case .redBerries:    return 3.5  // 5.  垂帘浆果: 0.7s 木质沉着复位
        case .lotusPod:      return 3.2  // 9.  珊瑚霞光球: 0.8s 稳健无回弹复位
        case .dandelion:     return 2.6  // 2.  珊瑚伞花: 1.0s 适中回弹
        case .cherryBlossom: return 2.4  // 10. 双色几何伞: 1.1s
        case .cornflower:    return 2.1  // 4.  几何风车: 1.2s 敏捷回弹
        case .bayWreath:     return 1.9  // 3.  孔雀彩扇: 1.4s 弹力双重振荡
        case .nightJasmine:  return 1.7  // 12. 极夜十二星: 1.5s 柔性回弹
        case .allium:        return 1.5  // 8.  珊瑚晶球: 1.7s 细杆弹性鞭梢振荡
        case .hawthorn:      return 1.3  // 1.  蓝金星芒: 1.9s 高杆缓慢回弹
        case .cosmos:        return 1.1  // 11. 经纬金晕葱: 2.2s 最长茎秆回弹时间
        }
    }

    /// 花头滞后晃动持续时间 (1.1s ~ 5.5s，茎杆停止后花头继续自振的持续秒数，相差 5 倍！)
    public var headWobbleDuration: Double {
        switch self {
        case .hydrangea:     return 1.1  // 7.  青绒蒲公英: 1.1 秒最短，几乎随茎秆立即静止
        case .mimosa:        return 1.6  // 6.  金琥珀阳: 1.6 秒微颤后静止
        case .lotusPod:      return 2.0  // 9.  珊瑚霞光球: 2.0 秒沉稳收尾
        case .cornflower:    return 2.6  // 4.  几何风车: 2.6 秒轻快风车自转式晃动
        case .dandelion:     return 3.0  // 2.  珊瑚伞花: 3.0 秒中度伞面摇曳
        case .redBerries:    return 3.4  // 5.  垂帘浆果: 3.4 秒钟摆式浆果垂摆
        case .nightJasmine:  return 3.7  // 12. 极夜十二星: 3.7 秒棱镜折光摆动
        case .cherryBlossom: return 4.0  // 10. 双色几何伞: 4.0 秒持久微波轻颤
        case .bayWreath:     return 4.3  // 3.  孔雀彩扇: 4.3 秒孔雀扇面余波
        case .allium:        return 4.6  // 8.  珊瑚晶球: 4.6 秒晶球弹性点头
        case .hawthorn:      return 5.0  // 1.  蓝金星芒: 5.0 秒巨星核低频持续深沉点头
        case .cosmos:        return 5.5  // 11. 经纬金晕葱: 5.5 秒最持久经纬浑天仪梦幻空灵长摇
        }
    }

    /// 花头自振晃动自然频率 (1.8 ~ 6.2 rad/s，决定晃动快慢节奏，相差 3.4 倍)
    public var headWobbleFrequency: Double {
        switch self {
        case .cornflower:    return 6.2  // 4.  几何风车: 高频轻盈飞速扇动
        case .cherryBlossom: return 5.5  // 10. 双色几何伞: 细腻快速微颤
        case .mimosa:        return 5.0  // 6.  金琥珀阳: 欢快碎步微颤
        case .hydrangea:     return 4.5  // 7.  青绒蒲公英: 短促紧凑晃动
        case .allium:        return 4.0  // 8.  珊瑚晶球: 弹跳轻灵
        case .nightJasmine:  return 3.5  // 12. 极夜十二星: 中频节奏
        case .bayWreath:     return 3.0  // 3.  孔雀彩扇: 优雅舒缓
        case .dandelion:     return 2.7  // 2.  珊瑚伞花: 柔美伞骨起伏
        case .cosmos:        return 2.4  // 11. 经纬金晕葱: 慢速空灵大弧度长波
        case .redBerries:    return 2.1  // 5.  垂帘浆果: 沉重浆果重力钟摆低频
        case .lotusPod:      return 2.0  // 9.  珊瑚霞光球: 凝重厚实
        case .hawthorn:      return 1.8  // 1.  蓝金星芒: 最沉稳磅礴的低频重力长摆
        }
    }

    /// 花头自振晃动偏摆角幅度 (0.08 ~ 0.48 弧度，决定晃动激烈程度，相差 6 倍！)
    public var headWobbleAmplitude: Double {
        switch self {
        case .cosmos:        return 0.48 // 11. 经纬金晕葱: ±27.5° 极其显著的大幅度深鞠点头
        case .allium:        return 0.42 // 8.  珊瑚晶球: ±24.0° 弹性鞭梢大幅甩动
        case .hawthorn:      return 0.38 // 1.  蓝金星芒: ±21.8° 恢弘深长点头
        case .cornflower:    return 0.35 // 4.  几何风车: ±20.0° 风车翼片灵动回旋摆动
        case .bayWreath:     return 0.30 // 3.  孔雀彩扇: ±17.2° 扇骨张合晃动
        case .cherryBlossom: return 0.28 // 10. 双色几何伞: ±16.0°
        case .dandelion:     return 0.25 // 2.  珊瑚伞花: ±14.3°
        case .nightJasmine:  return 0.22 // 12. 极夜十二星: ±12.6°
        case .redBerries:    return 0.20 // 5.  垂帘浆果: ±11.5°
        case .lotusPod:      return 0.15 // 9.  珊瑚霞光球: ±8.6°
        case .mimosa:        return 0.12 // 6.  金琥珀阳: ±6.9°
        case .hydrangea:     return 0.08 // 7.  青绒蒲公英: ±4.6° 极微小精巧克制微摆
        }
    }

    /// 花头基础等效迎风面积 (平方点数，反映花冠尺寸与迎风受力面积)
    public var headBaseArea: Double {
        switch self {
        case .cosmos:         return 12500.0 // 11. 经纬金晕葱: 360° 巨型经纬浑天仪 + 放射流线星冠 (迎风面积最大)
        case .lotusPod:       return 11000.0 // 9.  金晕绯瑰: 四重色阶水彩光晕 + 蜂巢九核拓扑 (巨型)
        case .cornflower:     return 9800.0  // 4.  几何风车: 8 刃星芒多边形棱镜风车 (大幅面)
        case .hawthorn:       return 9200.0  // 1.  蓝金星芒: 放射星核与金斑微光 (大幅面)
        case .allium:         return 7800.0  // 8.  珊瑚青瓣: 8 瓣展开青珊瑚 (中大型)
        case .bayWreath:      return 7200.0  // 3.  孔雀彩扇: 180° 彩扇梯阶面 (中大型)
        case .nightJasmine:   return 6800.0  // 12. 极夜十二星: 12 面体棱镜星芒 (中型)
        case .mimosa:         return 6200.0  // 6.  金琥珀阳: 密集放射阳花金针 (中型)
        case .cherryBlossom:  return 4800.0  // 10. 双色几何伞: 悬挂几何伞 (中小型)
        case .hydrangea:      return 4200.0  // 7.  青绒蒲公英: 蓬松轻巧绒球 (轻巧中小型)
        case .dandelion:      return 3600.0  // 2.  珊瑚伞花: 纤细轻盈小伞簇 (小而轻)
        case .redBerries:     return 3200.0  // 5.  垂帘浆果: 纤细下垂小浆果串 (迎风面积最小)
        }
    }

    /// 各阶段动态等效花头面积 (阶段 1 萌芽至阶段 4 全盛连续放大)
    public func effectiveHeadArea(progress: Double) -> Double {
        let stageScale: Double = {
            if progress < 0.25 {
                return 0.16 + (progress / 0.25) * 0.12
            } else if progress < 0.55 {
                return 0.28 + ((progress - 0.25) / 0.30) * 0.24
            } else if progress < 0.75 {
                return 0.52 + ((progress - 0.55) / 0.20) * 0.28
            } else {
                return 0.80 + min(1.0, (progress - 0.75) / 0.25) * 0.20
            }
        }()
        return headBaseArea * stageScale * pow(headScaleFactor, 2.0)
    }

    /// 花头个性化尺寸缩放因子 (用户精准定制：1 号蓝金星芒大 20%，4 号几何风车小 15%)
    public var headScaleFactor: CGFloat {
        switch self {
        case .hawthorn:   return 1.20 // 植物 1 号大 20%
        case .cornflower: return 0.85 // 植物 4 号小 15%
        default:          return 1.00
        }
    }

    /// 植物固有生长茎秆弧度基准值 (横向偏摆量，负数向左拱弯，正数向右拱弯，杜绝任何直板死线)
    public var naturalCurvature: CGFloat {
        switch self {
        case .dandelion:      return -22.0 // 2.  珊瑚伞花: 左侧外围下部竖直，上部向左舒展大弧
        case .cosmos:         return -32.0 // 11. 经纬金晕葱: 250pt 高杆，下部竖直，上部优雅向左挺拔大弧
        case .bayWreath:      return -20.0 // 3.  孔雀彩扇: 左侧自然外展大弧
        case .hydrangea:      return -14.0 // 7.  青绒蒲公英: 左中侧柔韧弧度
        case .cherryBlossom:  return -10.0 // 10. 双色几何伞: 靠近中央左侧微弧
        case .hawthorn:       return   6.0 // 1.  蓝金星芒: 中央高位挺拔主干，下挺拔上微秀
        case .nightJasmine:   return  12.0 // 12. 极夜十二星: 中央偏右优雅挺拔枝条
        case .lotusPod:       return  18.0 // 9.  珊瑚霞光球: 右内侧温润舒展
        case .redBerries:     return  24.0 // 5.  垂帘浆果: 右侧木质重果枝自然悬臂大弯
        case .allium:         return  28.0 // 8.  珊瑚青瓣: 右侧高位轻扬枝干
        case .cornflower:     return  32.0 // 4.  几何风车: 右侧外围扬起优美大弧线
        case .mimosa:         return  26.0 // 6.  金琥珀阳: 最右侧自然顺势舒展大弧
        }
    }

    /// 茎秆样式：部分植物采用圆点虚线（Dotted Beads），部分采用发丝实线矢量
    public var stemIsDotted: Bool {
        switch self {
        case .allium, .redBerries, .cosmos, .cherryBlossom:
            return true
        default:
            return false
        }
    }

    /// 是否为 2 倍大特异宏伟形态（伴随外围小光团与星尘粒子群）
    public var isGiantFlora: Bool {
        switch self {
        case .hawthorn, .cosmos, .lotusPod, .cornflower:
            return true
        default:
            return false
        }
    }

    public var palette: PosyPalette {
        switch self {
        case .hawthorn:
            // 1. 蓝金星芒 (Row 1-L): 莫兰迪靛青蓝 + 暖赭金
            return PosyPalette(
                primary: Color(red: 0.18, green: 0.25, blue: 0.45),
                secondary: Color(red: 0.28, green: 0.38, blue: 0.60),
                accent: Color(red: 0.90, green: 0.70, blue: 0.22),
                glow: Color(red: 0.92, green: 0.75, blue: 0.48).opacity(0.38),
                halo: Color(red: 0.88, green: 0.70, blue: 0.42).opacity(0.28),
                stamen: Color(red: 0.14, green: 0.18, blue: 0.32),
                stem: Color(red: 0.30, green: 0.38, blue: 0.48),
                pollens: [Color(red: 0.90, green: 0.70, blue: 0.22), Color(red: 0.18, green: 0.25, blue: 0.45), .white.opacity(0.9)]
            )
        case .dandelion:
            // 2. 珊瑚伞花 (Row 2-L): 莫兰迪珊瑚灰粉 + 柔和暖杏橙 + 琥珀金
            return PosyPalette(
                primary: Color(red: 0.85, green: 0.36, blue: 0.38),
                secondary: Color(red: 0.88, green: 0.55, blue: 0.38),
                accent: Color(red: 0.92, green: 0.74, blue: 0.25),
                glow: Color(red: 0.90, green: 0.60, blue: 0.48).opacity(0.40),
                halo: Color(red: 0.85, green: 0.45, blue: 0.38).opacity(0.28),
                stamen: Color(red: 0.38, green: 0.18, blue: 0.18),
                stem: Color(red: 0.36, green: 0.50, blue: 0.38),
                pollens: [Color(red: 0.92, green: 0.74, blue: 0.25), Color(red: 0.85, green: 0.36, blue: 0.38), .white.opacity(0.9)]
            )
        case .bayWreath:
            // 3. 孔雀彩扇 (Row 3-L): 莫兰迪抹茶灰绿 + 柔和珊瑚杏 + 哑光金
            return PosyPalette(
                primary: Color(red: 0.50, green: 0.75, blue: 0.25),
                secondary: Color(red: 0.88, green: 0.48, blue: 0.38),
                accent: Color(red: 0.92, green: 0.75, blue: 0.22),
                glow: Color(red: 0.65, green: 0.82, blue: 0.38).opacity(0.38),
                halo: Color(red: 0.88, green: 0.55, blue: 0.42).opacity(0.28),
                stamen: Color(red: 0.28, green: 0.42, blue: 0.18),
                stem: Color(red: 0.32, green: 0.48, blue: 0.30),
                pollens: [Color(red: 0.88, green: 0.48, blue: 0.38), Color(red: 0.50, green: 0.75, blue: 0.25), .white.opacity(0.9)]
            )
        case .cornflower:
            // 4. 几何风车 (Row 4-L): 莫兰迪烟灰青蓝 + 烟粉 + 灰紫
            return PosyPalette(
                primary: Color(red: 0.20, green: 0.68, blue: 0.72),
                secondary: Color(red: 0.85, green: 0.40, blue: 0.48),
                accent: Color(red: 0.55, green: 0.35, blue: 0.72),
                glow: Color(red: 0.30, green: 0.75, blue: 0.78).opacity(0.40),
                halo: Color(red: 0.58, green: 0.38, blue: 0.70).opacity(0.30),
                stamen: Color(red: 0.22, green: 0.18, blue: 0.32),
                stem: Color(red: 0.30, green: 0.50, blue: 0.45),
                pollens: [Color(red: 0.20, green: 0.68, blue: 0.72), Color(red: 0.85, green: 0.40, blue: 0.48), Color(red: 0.55, green: 0.35, blue: 0.72)]
            )
        case .redBerries:
            // 5. 垂帘浆果 (Row 5-L): 莫兰迪茜草暗绯 + 烟紫李 + 第戎芥末黄
            return PosyPalette(
                primary: Color(red: 0.76, green: 0.22, blue: 0.35),
                secondary: Color(red: 0.48, green: 0.22, blue: 0.44),
                accent: Color(red: 0.90, green: 0.80, blue: 0.25),
                glow: Color(red: 0.80, green: 0.32, blue: 0.45).opacity(0.38),
                halo: Color(red: 0.52, green: 0.20, blue: 0.42).opacity(0.28),
                stamen: Color(red: 0.32, green: 0.14, blue: 0.20),
                stem: Color(red: 0.48, green: 0.32, blue: 0.28),
                pollens: [Color(red: 0.90, green: 0.80, blue: 0.25), Color(red: 0.76, green: 0.22, blue: 0.35), Color(red: 0.48, green: 0.22, blue: 0.44)]
            )
        case .mimosa:
            // 6. 金琥珀阳 (Row 6-L): 莫兰迪暖琥珀金 + 灰茶粉 + 浅灰海绿
            return PosyPalette(
                primary: Color(red: 0.88, green: 0.65, blue: 0.18),
                secondary: Color(red: 0.82, green: 0.38, blue: 0.42),
                accent: Color(red: 0.22, green: 0.70, blue: 0.72),
                glow: Color(red: 0.90, green: 0.70, blue: 0.22).opacity(0.48),
                halo: Color(red: 0.88, green: 0.62, blue: 0.25).opacity(0.35),
                stamen: Color(red: 0.42, green: 0.28, blue: 0.12),
                stem: Color(red: 0.36, green: 0.48, blue: 0.32),
                pollens: [Color(red: 0.88, green: 0.65, blue: 0.18), Color(red: 0.22, green: 0.70, blue: 0.72), Color(red: 0.82, green: 0.38, blue: 0.42)]
            )
        case .hydrangea:
            // 7. 青绒蒲公英 (Row 1-R): 莫兰迪雾霭青 + 灰紫霞 + 柔黄
            return PosyPalette(
                primary: Color(red: 0.20, green: 0.65, blue: 0.70),
                secondary: Color(red: 0.58, green: 0.25, blue: 0.46),
                accent: Color(red: 0.90, green: 0.80, blue: 0.48),
                glow: Color(red: 0.28, green: 0.70, blue: 0.75).opacity(0.40),
                halo: Color(red: 0.58, green: 0.28, blue: 0.48).opacity(0.28),
                stamen: Color(red: 0.18, green: 0.30, blue: 0.35),
                stem: Color(red: 0.28, green: 0.45, blue: 0.42),
                pollens: [Color(red: 0.90, green: 0.80, blue: 0.48), Color(red: 0.20, green: 0.65, blue: 0.70), Color(red: 0.58, green: 0.25, blue: 0.46)]
            )
        case .allium:
            // 8. 珊瑚青瓣 (Row 2-R): 莫兰迪烟熏珊瑚 + 灰松石青 + 赭黄
            return PosyPalette(
                primary: Color(red: 0.85, green: 0.32, blue: 0.38),
                secondary: Color(red: 0.20, green: 0.68, blue: 0.70),
                accent: Color(red: 0.88, green: 0.62, blue: 0.20),
                glow: Color(red: 0.85, green: 0.45, blue: 0.48).opacity(0.40),
                halo: Color(red: 0.22, green: 0.65, blue: 0.68).opacity(0.30),
                stamen: Color(red: 0.16, green: 0.32, blue: 0.35),
                stem: Color(red: 0.30, green: 0.46, blue: 0.35),
                pollens: [Color(red: 0.20, green: 0.68, blue: 0.70), Color(red: 0.85, green: 0.32, blue: 0.38), Color(red: 0.88, green: 0.62, blue: 0.20)]
            )
        case .lotusPod:
            // 9. 金晕绯瑰 (Row 3-R): 莫兰迪灰玫红 + 灰梨绿 + 柔金光晕
            return PosyPalette(
                primary: Color(red: 0.82, green: 0.25, blue: 0.45),
                secondary: Color(red: 0.52, green: 0.75, blue: 0.22),
                accent: Color(red: 0.90, green: 0.70, blue: 0.20),
                glow: Color(red: 0.90, green: 0.70, blue: 0.25).opacity(0.48),
                halo: Color(red: 0.88, green: 0.65, blue: 0.28).opacity(0.35),
                stamen: Color(red: 0.35, green: 0.15, blue: 0.22),
                stem: Color(red: 0.35, green: 0.48, blue: 0.30),
                pollens: [Color(red: 0.90, green: 0.70, blue: 0.20), Color(red: 0.82, green: 0.25, blue: 0.45), Color(red: 0.52, green: 0.75, blue: 0.22)]
            )
        case .cherryBlossom:
            // 10. 双色几何伞 (Row 4-R): 莫兰迪柿橙 + 灰蔚蓝 + 哑光暖金
            return PosyPalette(
                primary: Color(red: 0.88, green: 0.48, blue: 0.22),
                secondary: Color(red: 0.22, green: 0.68, blue: 0.72),
                accent: Color(red: 0.88, green: 0.72, blue: 0.22),
                glow: Color(red: 0.88, green: 0.55, blue: 0.30).opacity(0.40),
                halo: Color(red: 0.22, green: 0.68, blue: 0.72).opacity(0.30),
                stamen: Color(red: 0.38, green: 0.22, blue: 0.14),
                stem: Color(red: 0.35, green: 0.42, blue: 0.36),
                pollens: [Color(red: 0.22, green: 0.68, blue: 0.72), Color(red: 0.88, green: 0.48, blue: 0.22), Color(red: 0.88, green: 0.72, blue: 0.22)]
            )
        case .cosmos:
            // 11. 经纬金晕葱 (Row 5-R): 莫兰迪灰鸢尾紫 + 地衣绿 + 暖花粉金
            return PosyPalette(
                primary: Color(red: 0.48, green: 0.22, blue: 0.68),
                secondary: Color(red: 0.45, green: 0.72, blue: 0.22),
                accent: Color(red: 0.90, green: 0.82, blue: 0.22),
                glow: Color(red: 0.90, green: 0.80, blue: 0.28).opacity(0.50),
                halo: Color(red: 0.88, green: 0.78, blue: 0.30).opacity(0.38),
                stamen: Color(red: 0.28, green: 0.15, blue: 0.38),
                stem: Color(red: 0.32, green: 0.45, blue: 0.28),
                pollens: [Color(red: 0.45, green: 0.72, blue: 0.22), Color(red: 0.90, green: 0.82, blue: 0.22), Color(red: 0.48, green: 0.22, blue: 0.68)]
            )
        case .nightJasmine:
            // 12. 极夜十二星 (Row 6-R): 莫兰迪暮色灰蓝 + 烟熏罗兰紫 + 柔白金星
            return PosyPalette(
                primary: Color(red: 0.22, green: 0.32, blue: 0.75),
                secondary: Color(red: 0.52, green: 0.25, blue: 0.74),
                accent: Color(red: 0.90, green: 0.70, blue: 0.20),
                glow: Color(red: 0.90, green: 0.70, blue: 0.28).opacity(0.48),
                halo: Color(red: 0.88, green: 0.68, blue: 0.30).opacity(0.35),
                stamen: Color(red: 0.16, green: 0.20, blue: 0.38),
                stem: Color(red: 0.28, green: 0.34, blue: 0.50),
                pollens: [Color(red: 0.90, green: 0.70, blue: 0.20), .white.opacity(0.9), Color(red: 0.22, green: 0.32, blue: 0.75)]
            )
        }
    }
}
