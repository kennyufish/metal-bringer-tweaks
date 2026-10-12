"""MetalTweaks panel: edits the MetalTweaks UE4SS mod's settings.txt and shows its live status.txt.
Lives inside the mod folder (ue4ss\\Mods\\MetalTweaks); the METALTWEAKS_DIR environment variable overrides that."""
import os
import time
import tkinter as tk
from tkinter import ttk

MOD_DIR = os.environ.get("METALTWEAKS_DIR") or os.path.dirname(os.path.abspath(__file__))
SETTINGS = os.path.join(MOD_DIR, "settings.txt")
STATUS = os.path.join(MOD_DIR, "status.txt")

FEATURES = [  # key, choices
    ("coin", [1, 2, 3, 4, 5, 8, 10]),
    ("disk", [1, 2, 3, 4, 5]),
    ("rarity", [1, 2, 4, 8]),
    ("exp", [1, 2, 3, 4, 5, 8, 10]),
]
STALE_SECONDS = 5  # status older than this = mod not running
LANGS = {"en": "English", "zh": "中文"}
TEXT = {
    "en": {
        "coin": "D.Chip gain", "disk": "Disk drop count", "rarity": "Rare chip (R4/R5) weight", "exp": "EXP gain",
        "off": "off", "pending": "Applying…", "active": "● On x{n}", "inactive": "○ Off",
        "conn_none": "● Mod not connected (game closed or MetalTweaks not loaded)",
        "conn_menu": "● Mod connected, waiting for a stage",
        "conn_floor": "● Mod connected, floor {floor}",
        "info": ("Extra D.Chip: +{coin_bonus}\nExtra disks dropped: {disk_extra}\n"
                 "R4/R5 share (this floor's bag): {rarity_share}\nExtra EXP: +{exp_bonus}\nLast: {last}"),
        "topmost": "Always on top", "lang": "Language",
        "no_mod": "MetalTweaks not found in {dir}\nKeep this panel inside ue4ss\\Mods\\MetalTweaks.",
        "save_fail": "Save failed: {err}",
    },
    "zh": {
        "coin": "D.Chip 获取倍率", "disk": "Disk 掉落数量倍率", "rarity": "高稀有度 (R4/R5) 权重", "exp": "EXP 获取倍率",
        "off": "关闭", "pending": "等待生效…", "active": "● 生效中 x{n}", "inactive": "○ 关闭",
        "conn_none": "● Mod 未连接（游戏没开或 MetalTweaks 没加载）",
        "conn_menu": "● Mod 已连接，等待进入关卡",
        "conn_floor": "● Mod 已连接，楼层 {floor}",
        "info": ("本次额外 D.Chip：+{coin_bonus}\n额外掉落 Disk：{disk_extra} 张\n"
                 "R4/R5 占比（本层袋子）：{rarity_share}\n额外 EXP：+{exp_bonus}\n最近：{last}"),
        "topmost": "窗口置顶", "lang": "语言",
        "no_mod": "在 {dir} 找不到 MetalTweaks\n请把面板放在 ue4ss\\Mods\\MetalTweaks 里。",
        "save_fail": "保存失败：{err}",
    },
}
INFO_DEFAULTS = {"coin_bonus": 0, "disk_extra": 0, "rarity_share": "-", "exp_bonus": 0, "last": ""}


def read_kv(path):
    try:
        with open(path, encoding="utf-8") as f:
            return dict(line.rstrip("\n").split("=", 1) for line in f if "=" in line)
    except OSError:
        return {}


class Panel(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Metal Bringer Tweaks")
        self.resizable(False, False)
        saved = read_kv(SETTINGS)
        self.lang = saved.get("lang") if saved.get("lang") in TEXT else "en"
        self.vars, self.boxes, self.names, self.state_labels = {}, {}, {}, {}
        frm = ttk.Frame(self, padding=12)
        frm.grid()
        for row, (key, choices) in enumerate(FEATURES):
            self.names[key] = ttk.Label(frm)
            self.names[key].grid(row=row, column=0, sticky="w", pady=3)
            cur = saved.get(key, "1")
            cur = int(cur) if cur.isdigit() and int(cur) in choices else 1
            self.vars[key] = tk.StringVar(value=self.label_of(cur))
            self.boxes[key] = ttk.Combobox(frm, textvariable=self.vars[key], state="readonly", width=10)
            self.boxes[key].grid(row=row, column=1, padx=8)
            self.boxes[key].bind("<<ComboboxSelected>>", lambda _e: self.save())
            self.state_labels[key] = ttk.Label(frm, width=16)
            self.state_labels[key].grid(row=row, column=2, sticky="w")
        r = len(FEATURES)
        ttk.Separator(frm).grid(row=r, column=0, columnspan=3, sticky="ew", pady=8)
        self.conn = ttk.Label(frm)
        self.conn.grid(row=r + 1, column=0, columnspan=3, sticky="w")
        self.info = ttk.Label(frm, justify="left")
        self.info.grid(row=r + 2, column=0, columnspan=3, sticky="w", pady=(4, 0))
        self.msg = ttk.Label(frm, foreground="#b00", justify="left")
        self.msg.grid(row=r + 3, column=0, columnspan=3, sticky="w")
        bottom = ttk.Frame(frm)
        bottom.grid(row=r + 4, column=0, columnspan=3, sticky="ew", pady=(6, 0))
        self.top = tk.BooleanVar(value=False)
        self.top_box = ttk.Checkbutton(bottom, variable=self.top,
                                       command=lambda: self.attributes("-topmost", self.top.get()))
        self.top_box.pack(side="left")
        self.lang_var = tk.StringVar(value=LANGS[self.lang])
        lang_box = ttk.Combobox(bottom, textvariable=self.lang_var, state="readonly", width=8,
                                values=list(LANGS.values()))
        lang_box.pack(side="right")
        lang_box.bind("<<ComboboxSelected>>", lambda _e: self.set_lang())
        self.lang_label = ttk.Label(bottom)
        self.lang_label.pack(side="right", padx=(0, 4))
        self.apply_lang()
        self.refresh()

    def t(self, key, **kw):
        return TEXT[self.lang][key].format(**kw)

    def label_of(self, n):
        return f"x1 ({self.t('off')})" if n == 1 else f"x{n}"

    def chosen(self, key):
        return int(self.vars[key].get().split()[0][1:])

    def set_lang(self):
        self.lang = next(code for code, name in LANGS.items() if name == self.lang_var.get())
        self.apply_lang()
        self.save()
        self.refresh(reschedule=False)

    def apply_lang(self):
        for key, choices in FEATURES:
            n = self.chosen(key)
            self.names[key].config(text=self.t(key))
            self.boxes[key].config(values=[self.label_of(c) for c in choices])
            self.vars[key].set(self.label_of(n))
        self.top_box.config(text=self.t("topmost"))
        self.lang_label.config(text=self.t("lang"))
        mod_ok = os.path.isfile(os.path.join(MOD_DIR, "Scripts", "main.lua"))
        self.msg.config(text="" if mod_ok else self.t("no_mod", dir=MOD_DIR))

    def save(self):
        tmp = SETTINGS + ".tmp"
        try:
            with open(tmp, "w", encoding="utf-8") as f:
                f.write("".join(f"{key}={self.chosen(key)}\n" for key, _c in FEATURES) + f"lang={self.lang}\n")
            os.replace(tmp, SETTINGS)  # atomic: the mod never reads a half-written file
        except OSError as e:
            self.msg.config(text=self.t("save_fail", err=e))

    def refresh(self, reschedule=True):
        s = read_kv(STATUS)
        try:
            alive = time.time() - int(s.get("updated", "0")) < STALE_SECONDS
        except ValueError:
            alive = False
        if not alive:
            self.conn.config(text=self.t("conn_none"), foreground="#888")
        elif s.get("ingame") != "1":
            self.conn.config(text=self.t("conn_menu"), foreground="#c80")
        else:
            self.conn.config(text=self.t("conn_floor", floor=s.get("floor", "?")), foreground="#080")
        for key, _c in FEATURES:
            applied = s.get(key)
            if not alive or applied is None or not applied.isdigit():
                text, color = "—", "#888"
            elif int(applied) != self.chosen(key):
                text, color = self.t("pending"), "#c80"
            elif applied == "1":
                text, color = self.t("inactive"), "#888"
            else:
                text, color = self.t("active", n=applied), "#080"
            self.state_labels[key].config(text=text, foreground=color)
        self.info.config(text=TEXT[self.lang]["info"].format_map({**INFO_DEFAULTS, **s}) if alive else "")
        if reschedule:
            self.after(1000, self.refresh)


if __name__ == "__main__":
    Panel().mainloop()
