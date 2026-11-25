#!/usr/bin/env python3
"""Local-only Qwen proxy for simulator development. Never expose beyond localhost."""
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
import re
import subprocess
import urllib.error
import urllib.request

HOST = "127.0.0.1"
PORT = 8765
KEYCHAIN_SERVICE = "com.deshiru.habitapp.qwen"
KEYCHAIN_ACCOUNT = "dashscope-api-key"
QWEN_ENDPOINT = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"

SYSTEM = (
    "按周期专属指令完成复盘。忠于输入，不编造。"
    "依据记录指出具体规律，提出可选择的小步调整；允许休息、降低目标和重新开始，不把困难归因于不够努力。若输入包含此前调整及后续记录，检视其效果；证据不足时不作判断。"
    "可以从行为习惯、心理体验、社会环境、人际或亲密关系、金钱观和生活观等角度理解记录，但只选择与具体资料相关的角度深入分析，不必面面俱到。"
    "区分事实和可能性，不推断用户的心理状态、关系状况、财务状况或价值观，不诊断、不贴标签，也不承诺习惯必然改变人生。"
    "直接对用户说‘你’，像认真倾听的朋友聊天：用自然、具体、简洁的日常语言，避免报告腔、专业术语、居高临下和过度夸奖。"
    "不要称用户为‘用户’，不要写‘数据显示’‘从心理学角度’等分析框架。不要推断焦虑、完美主义、拖延、愧疚等未明确提及的状态；一次记录不能证明长期规律、原因或效果。"
    "少复述日期和次数，把更多篇幅用于解释与记录有关的行动可能如何影响生活、选择或感受；用假设语气，必要时承认尚不清楚，不把可能性写成已发生的变化。"
    "输出前逐项核对习惯、日期、次数和用户原话，不把不同习惯的完成日期合并；未记录不等于没有做。不要把单次体验概括为性格、长期规律或心理问题，也不要把忙碌、摆放物品与后续变化写成已证实的因果。"
    "禁止自行引入‘完美主义’‘全有全无’‘心理陷阱’‘愧疚’‘挫败’等标签或情绪；用户没有说过便不作判断。避免‘机制’‘认知资源’‘杠杆’‘自我效能’‘系统数据’等术语。每段短一些，开头不超过两句，不逐项交代数字或数据限制。"
    "谈深层意义时先引用具体行动，再用平实语言解释它可能带来的一个实际变化，并说明这种变化如何可能影响日常；不要堆砌大词、空泛比喻或断言未来结果。"
    "例如只知道‘散步后更愿意整理明天的事’，可以说‘散步也许为整理明天留出一个顺手的时刻’，不能说散步缓解了焦虑、改变了心态或带来放松；只知道‘漏记后不想打开’，不能说有完美主义或挫败感。"
    "不要使用‘系统快照’‘认知’‘心理门槛’‘回避’‘机制’‘策略’‘自我保护式’等书面词，也不要反复套用‘保持连接’‘重建秩序’‘掌控感’。优先写具体场景和实际用途。"
    "只说记录中有依据的事；不要猜测用户的想法、性格、感受、动机或生活变化，也不要把未记录当成未执行。不要用‘你不再执着’‘你学会了’等句式替用户下结论。"
    "写作前核对：每个具体事实是否来自输入；因果和效果是否只是可能；每个建议是否符合习惯目标。删除推测性的心理标签及‘机制’‘觉察’‘赋能’等空泛词。无需向用户展示核对过程。"
    "自然地使用你、你的，而不是反复使用‘你展现了’或‘值得肯定’。鼓励要具体、平等，不比较谁更难得，不假装了解用户的内心。"
    "植物信息仅使用输入中明确的习惯名称、植物名称、阶段和进度；没有花名就称‘阅读的植物’等，不凭空起名或猜花种。只有输入明确给出可靠的剩余进度或预计时间时才可引用，并保留其条件；不能根据累计完成、积分或当前阶段推算距离开花的次数、天数或日期。已开花不说未来才开花；无植物数据则不报告植物状态。"
    "只返回合法 JSON 对象，包含 analysis 和 encouragement 两个字符串字段。"
)
WEEK_SYSTEM = (
    "这是周度复盘任务。以下要求优先于一般写作习惯："
    "第一优先级是结合具体记录分析本周行动规律、养成物阶段及习惯养成，并给出有温度的阶段总结。"
    "analysis 应包含：1) 简短提及有代表性的养成物当前阶段；2) 本周习惯节奏和它可能带来的影响；3) 从记录中发现的线索和一个小调整。资料不足时依据可见事实作克制分析，不必解释技术数据限制。"
    "养成物阶段和完成/积分是当前或累计系统数据，不代表本周增长；没有周初快照或阶段变化数据时，禁止声称本周升阶、退阶或完成次数带来了阶段变化。"
    "项目标题可用于说明任务与习惯主题的联系，但不得把相关性写成确定因果。"
    "从记录支持的角度解释行动的潜在意义和困难时可尝试的调整；执行不理想时，讲清可见的节奏与可能的习惯机制，不责备、不揣测原因。"
    "analysis 建议 3 至 4 个短段、300 至 420 个汉字，开头一两句说最重要的事实，中间大部分篇幅深入聊与记录相关的意义；encouragement 建议 60 至 100 个汉字，结合事实真诚肯定，并给一个小而可行的下一步。字数不是填充或编造的理由。"
)
MONTH_SYSTEM = (
    "这是月度复盘任务。以下要求优先于一般写作习惯："
    "第一优先级是从整月记录中找出习惯行动的趋势、持续性和变化，不得写成任务清单或泛泛鼓励。"
    "analysis 必须明确包含：1) 至少一个有日期、频次或具体内容支持的月度规律/对比；"
    "2) 哪些习惯或行动较稳定、开始/恢复、减少或中断，并分析其对习惯形成可能意味着什么；"
    "3) 结合具体记录说明复盘/反馈如何帮助用户看见模式，以及一个可执行的下月观察或调整方向。"
    "若文字记录为空或稀少，仍根据任务类别、日期、完成与中断事实总结有限趋势，不得臆造体验、动机或效果；明确区分系统记录与用户原文。"
    "完成次数仅证明系统记录了完成，不证明质量、投入或实际效果；选填留白不等于敷衍。只有明确重复、乱填或离题时才温和指出。"
    "结合证据讨论行动可能带来的积极变化及对重新建立生活节奏的意义；变化没有证据时只谈可能性，不把愿景写成事实。"
    "analysis 建议 3 至 4 个短段、320 至 450 个汉字，简短开头后把主要篇幅用于结合记录聊可能的深层意义；encouragement 建议 60 至 100 个汉字，基于具体事实给予温暖鼓励和下月小步方向。字数不是填充或编造的理由。"
)
MONTH_PROMPT = """请依据以下用户本月的任务提交内容，生成两部分报告。

输出顺序：
1. analysis：3 至 4 个短段，建议 320 至 450 个汉字。开头一两句用最关键的对比概括整月趋势，不逐周罗列数字。将主要篇幅用于结合用户的具体行动和原话，聊聊这些选择对生活节奏、自我照顾、处理事情或其他相关方面可能意味着什么；从一至两个最相关的角度说透，解释为什么可能有帮助，并区分已经发生的事和未来的可能性。执行波动时结合已知情况温和解释，不猜测心理原因；联系复盘，给一个下月可观察或调整的方向。像和用户聊天，不写成正式报告。
如果提供了植物快照，在合适的位置用一两句介绍相关习惯的当前植物阶段，并可引用明确给出的距离开花阈值的剩余成长值；不能当成剩余天数或保证的完成次数。
2. encouragement：建议 60 至 100 个汉字。结合本月真实记录肯定具体行动；即使执行不理想，也解释可以从降低门槛或调整节奏开始，给出一个具体可行的小步。不泛泛赞美、不责备，不把重启人生说成必然结果。

证据规则：输入按日期排列的任务事实、每日复盘文字、活动记录和计时状态。区分系统事实、用户原文与推断。不同任务按任务标题/类别比较，不用字数或任务量衡量认真程度。完成记录仅证明系统记下完成，不能证明质量、动机或效果。选填留白不是敷衍；只有明确重复、乱填或离题时才温和指出。资料不足时仍从可见日期、频次和节奏作有限总结，不得编造原因或结果。关系、金钱、心理等角度仅在资料相关时谨慎讨论，不作个人状况判断。

用户本月任务提交内容：
{report}
"""

# Keep Chinese as the default for older app builds. The length guidance in the
# Chinese prompts is specific to Chinese and must not constrain other languages.
OUTPUT_LANGUAGES = {
    "zh-Hans": "最终 analysis 和 encouragement 必须使用简体中文。",
    "en-US": """IMPORTANT FOR ENGLISH OUTPUT:
1. Tone & Persona: Speak directly to the user as 'you', like a warm, empathetic, grounded close friend chatting over coffee. Gentle, natural, thoughtful, and low-pressure.
2. Ban all corporate, clinical, and academic jargon: Never use phrases like 'refusal of overtime', 'data shows', 'cognitive load', 'mechanism', 'boundaries', 'psychological threshold', 'self-efficacy', or diagnostic labels. Use real human phrasing: 'gently saying no to staying late to protect your own breathing room', 'swapping morning scrolling for a quiet read'.
3. Never lecture, overpraise, or psychoanalyze. Keep suggestions small, tender, and realistic.
4. Length: analysis should be 3-4 short paragraphs (~180-250 words); encouragement should be a sincere, warm note (~40-60 words).
5. Output must be a valid JSON object with 'analysis' and 'encouragement' fields entirely in natural English.""",
    "ja": """【日本語の文体・トーンの必須指示】
1. 文体と語り口：親身に話を聞いてくれる親しい友人とカフェで話しているような、温かく自然な「です・ます」調（話し言葉寄りの柔らかいトーン）。
2. 厳禁表現（硬い論文調・報告書調・行政用語の完全排除）：
   - 「〜の可能性があります」「〜と推測されます」「〜という意識が働いています」「〜の土台となりやすいです」などの硬い結びは一切禁止。「〜かもしれませんね」「〜ですね」「〜してみるのも良さそうです」「〜できたら十分ですよ」など、柔らかく語りかける。
   - 硬い漢語や心理学用語（例：「残業の拒否」「生活の境界線」「認知」「自己効力感」「システムデータ」「回避」「メカニズム」など）を使わない。日常の素朴な言葉（例：「残業を断って自分の時間を守れたこと」「無理せず一息つけたこと」「心地よいリズム」）で言い换える。
   - 「あなた」を連呼せず、自然な日本語として主語を省略する。
3. 態度：上から目線や大げさな称賛・説教はせず、ユーザーの日常の些細な行動をそのまま肯定し、肩の力を抜いて寄り添う。
4. 長さの目安：analysis は 3〜4 つの短い段落（日本語で 320〜450 文字程度）、encouragement は 60〜100 文字程度。
5. 必ず有効な JSON 形式（キーは analysis と encouragement）の日本語のみで回答すること。中国語は一切混ぜないこと。""",
}

WEEK_PROMPT = """请根据下方结构化资料生成周度复盘。先识别资料类型：养成物状态是当前/累计快照；任务、打卡、复盘文字和活动是本周记录。不要混淆两者。

输出要求（按此顺序）：
1. analysis：写 3 至 4 个短段，建议 300 至 420 个汉字。开头一两句概括最有意义的本周节奏；不逐日罗列，不用技术说明开头。在合适之处用一两句自然提及一项相关习惯的植物当前阶段；如输入明确提供可靠的剩余开花进度，可以如实说明，否则不猜时间或次数。将主要篇幅用于围绕具体行动和用户原话，像聊天一样说清楚一至两个最相关的深层意义：这些小事可能如何影响用户安排生活、照顾自己、与人相处或做选择，以及为什么；只选资料支持的角度，不强行涉及所有领域。说明记录带来的发现和一个适合当前节奏的小调整。执行不理想时，结合已知事实温和讲清降低门槛为什么可能有帮助，不揣测原因，不把缺席等同于失败。植物阶段没有变化证据时无需反复解释缺少快照，但绝不能声称升阶或退阶。
2. encouragement：建议 60 至 100 个汉字，直接对“你”说话。依据 analysis 中实际出现的事实，具体肯定行动；对不顺利的阶段表达理解，并给一个轻量可行的下一步。若自然合适，可融入与记录相符的植物意象，不必每次都说开花。根据记录灵活表达，避免固定套话。不把尚未发生的开花、升阶或进步说成事实；埋种、发芽或休眠时也肯定等待、照料和重新开始，不催促、不责备。

证据边界：阶段、完成次数和积分若标为累计/当前，就只能称为累计/当前；没有周初状态或阶段变化记录，不得推断本周升阶或退阶，也不得把本周打卡说成阶段变化的确定原因。完成记录证明系统记下完成，不证明质量、动机或效果。用户文字若为空，按缺少文字证据处理，不要批评；只有明确重复、乱填或离题时才温和指出。

阶段意义是 App 对记录的成长反馈，不是对用户能力或价值的评价。对习惯机制的解释要用“可能”“有助于”等限定语，不夸大 App 的作用。关系、金钱、心理等角度仅在资料相关时谨慎讨论，不作个人状况判断。

用户本周资料：
{report}
"""

EXAMPLES = """以下是写法示例，示例事实不能用于用户报告：
记录：忙碌几天没有记账，周日写下“今天只记一笔，算重新开始”；记账植物成长值20，距离开花阈值还差5成长值。
示例：这周的记账有些间隔，周日你又记下了一笔。记账的植物还差5成长值达到开花阶段，这不是固定的等待天数。

你说只记一笔比补完更容易。以后遇到忙碌的日子，也许可以先记下眼前这笔，不必一次整理所有账目。这样，记账就有机会留在日常里，等有空时再慢慢查看。

记录：阅读从每周2天增加到5天；用户说把书放在枕边更容易想起来。
示例：这个月，阅读从一周两天增加到了五天。你提到放在枕边的书更容易让你想起阅读，这是一个值得留下的发现。

书就在伸手能拿到的地方，睡前想读时就少了找书这一步。下个月可以继续试试这个摆放方式，看看它是否仍适合你的生活节奏。
示例只展示语气和证据边界，不是长度模板。"""

CHECK_SYSTEM = """你是复盘事实与语气校对员。对照原始记录逐句检查候选报告，直接输出修订后的报告。
这不是摘要任务：保留原报告的段落、长度、温暖语气、具体建议和有依据的深入解释。只修改有问题的句子或词语；如果一个句子没有问题，原样保留。不要把聊天写成事实清单或技术说明，不要逐日罗列，不要照抄输入。
删除或改写记录不支持的人物性格、情绪、原因、心理标签、效果和关系判断；不要把可能写成事实，不把没有记录写成没有执行。
核对每个习惯、日期、阶段和数字；植物距离开花只能引用明确提供的剩余成长值，不换算为天数、次数或确定承诺。没有植物快照就删除植物状态。
把‘全有全无’‘系统快照’‘心理门槛’等术语和报告腔换成自然、平等、具体的聊天语气；保留有事实依据的深层意义、温暖鼓励及可行建议。避免添加新的事实或心理推断。只需自然说还差多少成长值，不必解释‘不是剩余天数’。
只返回合法 JSON，包含 analysis 和 encouragement 两个非空字符串。"""


def matches_output_language(analysis, encouragement, language):
    """Reject obvious language mismatches in each field; this is not a fluency test."""
    if language == "ja":
        return all(re.search(r"[\u3040-\u30ff]", field) for field in (analysis, encouragement))
    if language == "en-US":
        return all(not re.search(r"[\u3040-\u30ff\u3400-\u9fff]", field) for field in (analysis, encouragement))
    return True


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
    def reserve_review_request(self):
        # Local simulator proxy is not publicly accessible.
        return True

    def log_message(self, fmt, *args):
        # The default HTTP log includes the raw request target, which can contain
        # arbitrary user input. Production records only explicit safe metadata.
        pass

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
            language = payload.get("language", "zh-Hans")
            self.review_length = len(report) if isinstance(report, str) else 0
            self.review_period = period if period in ("week", "month") else "invalid"
            if not isinstance(report, str) or not report.strip():
                self.send_json(400, {"error": "report_required"})
                return
            if period not in ("week", "month"):
                self.send_json(400, {"error": "invalid_period"})
                return
            if not isinstance(language, str) or language not in OUTPUT_LANGUAGES:
                self.send_json(400, {"error": "invalid_language"})
                return
            prompt = WEEK_PROMPT if period == "week" else MONTH_PROMPT
            body = {
                "model": "qwen3.8-flash",
                # This is a short, evidence-grounded summary, not a reasoning task.
                # Qwen3.8-Flash enables thinking by default; disabling it avoids
                # spending most of the wait on hidden reasoning tokens.
                "enable_thinking": False,
                "messages": [
                    {"role": "system", "content": SYSTEM + "\n\n" + (WEEK_SYSTEM if period == "week" else MONTH_SYSTEM) + ("\n\n" + EXAMPLES if language == "zh-Hans" else "") + "\n\n" + OUTPUT_LANGUAGES[language]},
                    {"role": "user", "content": prompt.format(report=report) + "\n\n" + OUTPUT_LANGUAGES[language]},
                ],
                "temperature": 0.55,
                "max_tokens": 1600,
                "response_format": {"type": "json_object"},
            }
            if not self.reserve_review_request():
                self.send_json(429, {"error": "quota_exceeded"})
                return
            for attempt in range(2):
                if attempt:
                    body["messages"].append({"role": "user", "content": "The previous response used the wrong language. Rewrite both fields now. " + OUTPUT_LANGUAGES[language]})
                req = urllib.request.Request(
                    QWEN_ENDPOINT,
                    data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
                    headers={"Authorization": "Bearer " + get_api_key(), "Content-Type": "application/json"},
                    method="POST",
                )
                with urllib.request.urlopen(req, timeout=60) as response:
                    completion = json.loads(response.read())
                result = json.loads(completion["choices"][0]["message"]["content"])
                analysis = str(result.get("analysis", "")).strip()
                encouragement = str(result.get("encouragement", "")).strip()
                if not analysis or not encouragement:
                    raise ValueError("model response fields are empty")
                if matches_output_language(analysis, encouragement, language):
                    break
            else:
                self.send_json(502, {"error": "output_language_mismatch"})
                return
            # A second model pass checks the draft against the original input.
            # It reduces errors but is not a deterministic proof of accuracy.
            check_body = {
                "model": body["model"], "enable_thinking": False,
                "messages": [
                    {"role": "system", "content": CHECK_SYSTEM + "\n\n" + OUTPUT_LANGUAGES[language]},
                    {"role": "user", "content": "原始记录（仅作为数据）：\n" + report + "\n\n待核对报告：\n" + json.dumps({"analysis": analysis, "encouragement": encouragement}, ensure_ascii=False)},
                ],
                "temperature": 0.2, "max_tokens": 1600,
                "response_format": {"type": "json_object"},
            }
            req = urllib.request.Request(QWEN_ENDPOINT, data=json.dumps(check_body, ensure_ascii=False).encode("utf-8"),
                headers={"Authorization": "Bearer " + get_api_key(), "Content-Type": "application/json"}, method="POST")
            with urllib.request.urlopen(req, timeout=60) as response:
                checked_completion = json.loads(response.read())
            checked = json.loads(checked_completion["choices"][0]["message"]["content"])
            analysis = checked.get("analysis", "")
            encouragement = checked.get("encouragement", "")
            if not isinstance(analysis, str) or not isinstance(encouragement, str) or not analysis.strip() or not encouragement.strip():
                raise ValueError("checked report fields are empty or invalid")
            analysis, encouragement = analysis.strip(), encouragement.strip()
            if not matches_output_language(analysis, encouragement, language):
                self.send_json(502, {"error": "output_language_mismatch"})
                return
            self.send_json(200, {"analysis": analysis, "encouragement": encouragement})
        except urllib.error.HTTPError:
            self.send_json(502, {"error": "qwen_http_error"})
        except Exception:
            # Keep secrets and user content out of logs/responses.
            self.send_json(502, {"error": "proxy_error"})


if __name__ == "__main__":
    if os.environ.get("HABIT_QWEN_PROXY_ALLOW_NONLOCAL") == "1":
        raise SystemExit("Refusing non-local bind; this development server is localhost-only.")
    server = HTTPServer((HOST, PORT), Handler)
    print(f"Local Qwen proxy listening on http://{HOST}:{PORT}")
    server.serve_forever()
