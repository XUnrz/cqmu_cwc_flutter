#!/usr/bin/env python3
"""根据 API抓取.md 生成 lib/data/api_catalog.dart。

用法：python3 tool/gen_api_catalog.py
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "API抓取.md"
DST = ROOT / "lib" / "data" / "api_catalog.dart"

# 路径词 → 中文（按 camelCase 拆分后逐词翻译，未收录的词保留原文）
WORDS = {
    "get": "查询", "query": "查询", "add": "新增", "del": "删除", "delete": "删除",
    "modify": "修改", "update": "更新", "edit": "编辑", "set": "设置", "list": "列表",
    "page": "分页", "total": "汇总", "detail": "详情", "details": "详情", "apply": "申请",
    "pay": "支付", "cancel": "取消", "verify": "审核", "audit": "审核", "info": "信息",
    "account": "账户", "balance": "余额", "bank": "银行", "binding": "绑定", "bind": "绑定",
    "unbind": "解绑", "status": "状态", "loss": "挂失", "unloss": "解挂", "transaction": "交易",
    "key": "密钥", "result": "结果", "recharge": "充值", "refund": "退款", "bill": "账单",
    "fee": "费用", "ele": "电费", "water": "水费", "room": "房间", "build": "楼栋",
    "area": "区域", "meter": "电表", "day": "日", "value": "值", "dorm": "宿舍",
    "employee": "人员", "emp": "人员", "bed": "床位", "out": "校外", "leave": "离校",
    "credit": "信用", "loan": "借款", "study": "学费", "generation": "学杂费",
    "parking": "停车", "park": "停车", "mtn": "月租", "temp": "临时", "car": "车辆",
    "no": "编号", "plate": "车牌", "seat": "车位", "speed": "测速", "record": "记录",
    "history": "历史", "shop": "商铺", "rent": "租金", "consume": "消费",
    "dinner": "订餐", "order": "订单", "type": "类型", "market": "消费", "sum": "汇总",
    "notice": "通知", "tops": "置顶", "device": "设备", "lock": "门锁", "pwd": "密码",
    "rola": "门禁", "hqc": "后勤", "location": "位置", "salary": "工资", "tender": "招标",
    "receivable": "应收", "statistics": "统计", "report": "报表", "department": "部门",
    "college": "学院", "grade": "年级", "dk": "贷款", "ylmz": "医疗门诊",
    "feecollect": "收费", "tempcard": "临时卡", "guest": "访客", "menu": "菜单",
    "menus": "菜单", "captcha": "验证码", "image": "图片", "login": "登录",
    "logout": "登出", "resetpw": "重置密码", "send": "发送", "forget": "找回密码",
    "ticket": "票据", "open": "开放", "id": "ID", "check": "校验", "extend": "扩展",
    "face": "人脸", "photo": "照片", "fogetpwd": "忘记密码", "all": "全部",
    "person": "个人", "teacher": "教师", "batch": "批量", "change": "变更",
    "sure": "确认", "choose": "选择", "stu": "学生", "new": "新", "config": "配置",
    "user": "用户", "role": "角色", "building": "楼栋", "entrance": "入口",
    "nearest": "最近", "success": "成功", "scanning": "扫码", "create": "创建",
    "qrcode": "二维码", "moveoutblack": "移出黑名单", "subsidy": "补贴",
    "visit": "来访", "meeting": "会议", "train": "培训", "receipt": "收据",
    "other": "其他", "charge": "充值", "score": "积分", "free": "免费",
    "upload": "上传", "file": "文件", "df": "代付", "big": "大额", "month": "月份",
    "wx": "微信", "trans": "交易", "code": "验证码", "msg": "短信", "message": "短信",
    "monthly": "月租", "space": "车位", "callback": "回调", "move": "移出",
    "with": "按", "by": "按", "wf": "微信", "jf": "缴费", "money": "金额",
    "perform": "履约", "item": "项目", "obj": "对象", "collect": "收款",
    "his": "历史", "state": "状态", "sj": "数据", "bmsd": "报名收费",
    "y": "年", "nd": "年度", "xy": "学院", "zy": "专业", "bj": "班级", "nj": "年级",
    "newstu": "新生", "outbed": "退宿", "instrutor": "辅导员", "applybed": "申请床位",
    "sweep": "扫码", "payinfo": "支付信息", "totals": "合计", "select": "选择",
    "s": "", "new_": "", "r": "", "vo": "", "alumni": "校友", "gust": "访客", "unbindwechat": "解绑微信", "facephotocheck": "人脸照片校验", "bindingset": "绑定设置",
    # 模块级词
    "card": "校园卡", "eaccount": "电子卡", "baseconfig": "基础配置",
    "filecontroller": "文件", "roombed": "宿舍床位", "outemployee": "校外人员",
    "carspeedcontroller": "车辆测速", "carcontroller": "车辆", "cwc": "财务",
    "wxgzxx": "工资", "wechat": "微信", "un": "解", "4g": "4G",
    "water4g": "4G水控", "shop": "商铺", "dinner": "订餐", "credit": "信用",
    "rola": "门禁", "lock": "门锁", "leave": "离校", "hqc": "后勤",
    "market": "消费", "notice": "通知", "device": "设备", "sf": "水费",
    "controller": "", "speed": "测速",
}


def translate(path: str, module: str = "") -> str:
    segments = [s for s in path.strip("/").split("/") if s and s != "v2"]
    out = []
    for seg in segments:
        # camelCase / snake_case 拆分（含 4G、Alumni 这类混合写法）
        s = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1 \2", seg)
        s = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", s)
        s = re.sub(r"([A-Z])([A-Z][a-z])", r"\1 \2", s)
        parts = s.replace("_", " ").split()
        words = [
            WORDS.get(p.lower(), WORDS.get(p.lower().rstrip("0123456789"), p))
            for p in parts
        ]
        text = "".join(words)
        if text and text not in out:
            out.append(text)
    # 模块名已表达的含义不再重复（如 module=校园卡, path=/card/info/get）
    if module and len(out) > 1 and out[0] in module:
        out = out[1:]
    return " · ".join(out) if out else path


def split_params(raw: str) -> tuple[list[str], dict[str, str]]:
    raw = raw.strip()
    if raw in ("", "—", "-", "无"):
        return [], {}
    # 按“逗号 + 新参数名”切分，避免拆开表达式内部的逗号
    chunks = re.split(r",\s*(?=[A-Za-z_][A-Za-z0-9_]*\s*(?:=|,|$))", raw)
    names: list[str] = []
    defaults: dict[str, str] = {}
    for chunk in chunks:
        chunk = chunk.strip()
        if not chunk:
            continue
        if "=" in chunk:
            name, value = chunk.split("=", 1)
            name = name.strip()
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
                continue
            value = value.strip()
            if name not in names:
                names.append(name)
            # 只保留纯数字 / 单层 a/b / 字符串字面量作为默认值
            m = re.fullmatch(r"-?\d+(?:\.\d+)?", value)
            if m:
                defaults[name] = value
            else:
                m = re.fullmatch(r"(\d+)\s*/\s*\d+", value)
                if m:
                    defaults[name] = m.group(1)
                else:
                    m = re.fullmatch(r"'([^']*)'|\"([^\"]*)\"", value)
                    if m:
                        defaults[name] = m.group(1) if m.group(1) is not None else m.group(2)
        else:
            m = re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", chunk)
            if m and m.group(0) not in names:
                names.append(m.group(0))
    return names, defaults


def dart_map(d: dict[str, str]) -> str:
    if not d:
        return "<String, String>{}"
    items = ", ".join(f"'{k}': '{v}'" for k, v in d.items())
    return f"<String, String>{{{items}}}"


def dart_list(items: list[str]) -> str:
    if not items:
        return "<String>[]"
    return "<String>[" + ", ".join(f"'{i}'" for i in items) + "]"


def main() -> None:
    text = SRC.read_text(encoding="utf-8")
    entries: list[dict] = []
    module = ""

    # 标题 → 模块名
    for line in text.splitlines():
        m = re.match(r"^###\s+\d+\.\d+\s+(.+)$", line)
        if m:
            module = m.group(1).strip()
            if module.startswith("其他登录"):
                module = "登录 / 认证"
            continue
        if not module or not line.startswith("|"):
            continue
        m = re.match(
            r"^\|\s*`(/[^`]+)`\s*\|\s*([A-Z]+)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|$", line
        )
        if not m:
            continue
        path, method, raw_params, auth = m.groups()
        if path == "/login/doLogin":
            continue  # 由登录页专门处理（下方手工加入）
        params, defaults = split_params(raw_params)
        entries.append(
            {
                "method": method,
                "path": path,
                "module": module,
                "description": translate(path, module),
                "params": params,
                "defaults": defaults,
                "token": "✅" in auth,
            }
        )

    # 密码登录：参数固定，密码需 AES 加密
    entries.insert(
        0,
        {
            "method": "POST",
            "path": "/login/doLogin",
            "module": "登录 / 认证",
            "description": "账号密码登录（密码自动 AES 加密）",
            "params": ["userno", "password", "openId", "validateCode", "token", "loginCode"],
            "defaults": {"token": "", "validateCode": "", "loginCode": ""},
            "token": False,
            "encrypt": True,
        },
    )

    lines = [
        "// GENERATED FILE —— 由 tool/gen_api_catalog.py 根据 API抓取.md 生成，请勿手改。",
        f"// 共 {len(entries)} 个端点。",
        "library;",
        "",
        "import '../models/api_endpoint.dart';",
        "",
        "const List<ApiEndpoint> apiCatalog = <ApiEndpoint>[",
    ]
    for e in entries:
        extra = []
        if e.get("encrypt"):
            extra.append("encryptPassword: true")
        if e["path"] == "/filecontroller/upload":
            extra.append("isUpload: true")
        extra_text = (", " + ", ".join(extra)) if extra else ""
        lines.append(
            "  ApiEndpoint(method: '{method}', path: '{path}', module: '{module}', "
            "description: '{description}', params: {params}, defaults: {defaults}, "
            "requireToken: {token}{extra}),".format(
                method=e["method"],
                path=e["path"],
                module=e["module"],
                description=e["description"],
                params=dart_list(e["params"]),
                defaults=dart_map(e["defaults"]),
                token="true" if e["token"] else "false",
                extra=extra_text,
            )
        )
    lines.append("];")
    lines.append("")
    DST.write_text("\n".join(lines), encoding="utf-8")
    print(f"生成 {len(entries)} 个端点 → {DST}")


if __name__ == "__main__":
    main()
