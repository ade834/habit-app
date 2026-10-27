#!/usr/bin/env python3
"""Local-only Qwen proxy for simulator development. Never expose beyond localhost."""
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
import subprocess
import urllib.error
import urllib.request

HOST = "127.0.0.1"
PORT = 8765
KEYCHAIN_SERVICE = "com.deshiru.habitapp.qwen"
KEYCHAIN_ACCOUNT = "dashscope-api-key"
QWEN_ENDPOINT = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"

SYSTEM = (
    "按周期专属指令完成中文复盘。忠于输入，不编造。"
    "只返回合法 JSON 对象，包含 analysis 和 encouragement 两个字符串字段。"
)
WEEK_SYSTEM = (
    "这是周度复盘任务。以下要求优先于一般写作习惯："
    "第一优先级是分析养成物阶段及习惯养成，不得让泛泛鼓励、挑错或其他话题取代这两个重点。"
    "analysis 必须明确包含：1) 养成物当前阶段及其含义；2) 本周相关项目/习惯的完成节奏如何可能支持、维持或暂缓成长；"
    "3) 记录与反馈如何帮助看见规律、形成稳定提示和反馈。三项都要出现，资料不足时依据可见事实作克制分析，不得省略主题。"
    "养成物阶段和完成/积分是当前或累计系统数据，不代表本周增长；没有周初快照或阶段变化数据时，禁止声称本周升阶、退阶或完成次数带来了阶段变化。"
    "项目标题可用于说明任务与习惯主题的联系，但不得把相关性写成确定因果。"
    "analysis 写 2 至 3 段，建议 180 至 280 个汉字，优先保证上述三项完整。encouragement 必须结合本周事实，先具体肯定用户真实做到了的坚持、耐心、勇气、觉察或重新开始，再温柔鼓励用户继续养成习惯；自然融入‘你陪伴植物成长，日常照料积累后植物会开出惊喜的花朵’这一意象，并给一个小而可行的下一步。每次按记录变化表达，避免固定套话。不得谎称植物已经开花或已经升阶；未开花时用期待语气表达。"
)
MONTH_SYSTEM = (
    "这是月度复盘任务。以下要求优先于一般写作习惯："
    "第一优先级是从整月记录中找出习惯行动的趋势、持续性和变化，不得写成任务清单或泛泛鼓励。"
    "analysis 必须明确包含：1) 至少一个有日期、频次或具体内容支持的月度规律/对比；"
    "2) 哪些习惯或行动较稳定、开始/恢复、减少或中断，并分析其对习惯形成可能意味着什么；"
    "3) 结合具体记录说明复盘/反馈如何帮助用户看见模式，以及一个可执行的下月观察或调整方向。"
    "若文字记录为空或稀少，仍根据任务类别、日期、完成与中断事实总结有限趋势，不得臆造体验、动机或效果；明确区分系统记录与用户原文。"
    "完成次数仅证明系统记录了完成，不证明质量、投入或实际效果；选填留白不等于敷衍。只有明确重复、乱填或离题时才温和指出。"
    "analysis 写 2 至 3 段，建议 200 至 280 个汉字，优先保证三项重点完整。encouragement 基于分析中的具体事实，给出一个小而可行的下一步。"
)
MONTH_PROMPT = """请依据以下用户本月的任务提交内容，生成两部分报告。

输出顺序：
1. analysis：2 至 3 个自然段。先写整月最清楚的行动规律和具体证据；再写稳定、恢复、减少或中断的习惯及其可能意义；最后联系复盘反馈，提出一个下月可观察或调整的方向。建议 200 至 280 个汉字。不得只罗列任务，不得用无关领域的泛化分析填充篇幅。
2. encouragement：用一句具体、温和的话承接 analysis，给出小步可行的建议；不泛泛赞美、不责备。

证据规则：输入按日期排列的任务事实、每日复盘文字、活动记录和计时状态。区分系统事实、用户原文与推断。不同任务按任务标题/类别比较，不用字数或任务量衡量认真程度。完成记录仅证明系统记下完成，不能证明质量、动机或效果。选填留白不是敷衍；只有明确重复、乱填或离题时才温和指出。资料不足时仍从可见日期、频次和节奏作有限总结，不得编造原因或结果。只讨论记录支持的习惯养成和行为规律，不引入无关的关系、经济或心理话题。

用户本月任务提交内容：
{report}
"""

WEEK_PROMPT = """请根据下方结构化资料生成周度复盘。先识别资料类型：养成物状态是当前/累计快照；任务、打卡、复盘文字和活动是本周记录。不要混淆两者。

输出要求（按此顺序）：
1. analysis：写 2 至 3 个自然段。第一段必须概括养成物的阶段分布，并选择有代表性的阶段说明它反映的累计记录状态；第二段必须联系本周具体习惯/项目的完成日期、频次、持续或中断，分析这些行动可能如何支持、维持或暂缓相关养成物成长；最后必须点明记录与复盘如何帮助发现行动规律、建立提示和反馈、支持习惯形成。不能只写任务完成情况，也不能只给鼓励。建议 180 至 280 个汉字。
2. encouragement：基于 analysis 中实际出现的记录，用 1 至 2 句直接对“你”说温暖、具体的鼓励，并给一个轻量可行的下一步。鼓励你持续养成习惯，也把每一次真实行动写成你陪伴植物成长的一份心意：随着照料与记录积累，植物会在你的陪伴下开出惊喜的花朵。根据本周的阶段和行动灵活“花样夸夸”，可以肯定坚持、耐心、勇气、觉察或重新开始；每次换用贴合记录的表达，不重复固定套话。不得把尚未发生的开花、升阶或进步说成事实；植物处于埋种、发芽或休眠阶段时，也要肯定等待、照料和重新开始，不催促、不责备。

证据边界：阶段、完成次数和积分若标为累计/当前，就只能称为累计/当前；没有周初状态或阶段变化记录，不得推断本周升阶或退阶，也不得把本周打卡说成阶段变化的确定原因。完成记录证明系统记下完成，不证明质量、动机或效果。用户文字若为空，按缺少文字证据处理，不要批评；只有明确重复、乱填或离题时才温和指出。

阶段意义是 App 对记录的成长反馈，不是对用户能力或价值的评价。对习惯机制的解释要用“可能”“有助于”等限定语，不夸大 App 的作用。只讨论与本周数据相关的习惯养成内容，不要引入关系、经济、心理等无关话题。

用户本周资料：
{report}
"""


def get_api_key():
    return subprocess.check_output(
        [
            "/usr/bin/security", "find-generic-password", "-s", KEYCHAIN_SERVICE,
            "-a", KEYCHAIN_ACCOUNT, "-w",
        ],
        text=True,
        stderr=subprocess.DEVNULL,
    ).strip()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        # Do not log request bodies or user-submitted reflection text.
        print("%s - %s" % (self.address_string(), fmt % args))

    def send_json(self, status, obj):
        data = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(data)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.end_headers()

    def do_GET(self):
        if self.path == "/health":
            self.send_json(200, {"status": "ok", "model": "qwen3.8-flash"})
        else:
            self.send_json(404, {"error": "not_found"})

    def do_POST(self):
        # Keep the former monthly path as an alias for already installed simulator builds.
        if self.path not in ("/api/review", "/api/monthly-review"):
            self.send_json(404, {"error": "not_found", "expected": "/api/review"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            # Keep a generous local payload cap. Never silently truncate a month's samples.
            if length <= 0 or length > 800_000:
                self.send_json(413, {"error": "invalid_payload_size"})
                return
            payload = json.loads(self.rfile.read(length))
            report = payload.get("report", "")
            period = payload.get("period", "month")
            if not isinstance(report, str) or not report.strip():
                self.send_json(400, {"error": "report_required"})
                return
            if period not in ("week", "month"):
                self.send_json(400, {"error": "invalid_period"})
                return
            prompt = WEEK_PROMPT if period == "week" else MONTH_PROMPT
            body = {
                "model": "qwen3.8-flash",
                # This is a short, evidence-grounded summary, not a reasoning task.
                # Qwen3.8-Flash enables thinking by default; disabling it avoids
                # spending most of the wait on hidden reasoning tokens.
                "enable_thinking": False,
                "messages": [
                    {"role": "system", "content": SYSTEM + "\n\n" + (WEEK_SYSTEM if period == "week" else MONTH_SYSTEM)},
                    {"role": "user", "content": prompt.format(report=report)},
                ],
                "temperature": 0.55,
                "max_tokens": 1000,
                "response_format": {"type": "json_object"},
            }
            req = urllib.request.Request(
                QWEN_ENDPOINT,
                data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
                headers={
                    "Authorization": "Bearer " + get_api_key(),
                    "Content-Type": "application/json",
                },
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=60) as response:
                completion = json.loads(response.read())
            content = completion["choices"][0]["message"]["content"]
            result = json.loads(content)
            analysis = str(result.get("analysis", "")).strip()
            encouragement = str(result.get("encouragement", "")).strip()
            if not analysis or not encouragement:
                raise ValueError("model response fields are empty")
            self.send_json(200, {"analysis": analysis, "encouragement": encouragement})
        except urllib.error.HTTPError as exc:
            self.send_json(502, {"error": "qwen_http_error", "status": exc.code})
        except Exception as exc:
            # Keep secrets and user content out of logs/responses.
            self.send_json(502, {"error": "proxy_error", "detail": type(exc).__name__})


if __name__ == "__main__":
    if os.environ.get("HABIT_QWEN_PROXY_ALLOW_NONLOCAL") == "1":
        raise SystemExit("Refusing non-local bind; this development server is localhost-only.")
    server = HTTPServer((HOST, PORT), Handler)
    print(f"Local Qwen proxy listening on http://{HOST}:{PORT}")
    server.serve_forever()
