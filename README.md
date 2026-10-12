# metal-bringer-tweaks | MetalTweaks

An unofficial [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) Lua mod for **Metal Bringer** (Steam, single-player) with a small settings window.
Every option defaults to x1 (off). Changes apply in about one second, without restarting the game.

| Option | Choices | What it does |
|---|---|---|
| D.Chip gain | x1–x10 | Each D.Chip pickup counts N times. Spending is untouched. |
| Disk drop count | x1–x5 | Each disk the game drops brings N−1 extra disks, drawn from the same floor's chip pool. |
| Rare chip (R4/R5) weight | x1, x2, x4, x8 | Rank 4/5 chips become N times as likely, among the chips the current floor allows. |
| EXP gain | x1–x10 | Every EXP grant counts N times. Level-ups are handled by the game as usual. |

The mod only changes values in memory while you play. It doesn't touch game files or the save format, but whatever you earn while it's on is saved as normal progress.

## Requirements

- Metal Bringer on Steam, Windows. Tested with Steam build 18359301.
- UE4SS **experimental** build: grab `UE4SS_v3.0.1-....zip` from the [`experimental-latest` release](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest). The mod uses `LoopInGameThreadWithDelay`, which the older stable 3.0.1 release lacks.
- For the settings window: [Python 3](https://www.python.org/downloads/) with tkinter (included in the python.org installer). Without Python you can edit `settings.txt` by hand (see below).

## Install

1. Install UE4SS: extract the zip into `...\steamapps\common\Metal Bringer\MetalBringer\Binaries\Win64\`, so that `dwmapi.dll` and the `ue4ss` folder sit next to `MetalBringer-Win64-Shipping.exe`.
2. Copy the `MetalTweaks` folder from this repo into `...\Binaries\Win64\ue4ss\Mods\`.
3. Start the game. `ue4ss\UE4SS.log` should contain `[MetalTweaks] loaded`.
4. Double-click `ue4ss\Mods\MetalTweaks\MetalTweaksPanel.cmd` to open the settings window. Make a desktop shortcut to it if you like.

The window shows whether the mod is connected, which options are active, and what has been added so far this session. Language: English or 中文 (bottom right).

### Without Python

The mod creates `ue4ss\Mods\MetalTweaks\settings.txt` on first start. Edit the numbers and save; the mod picks them up within a second:

```
coin=2
disk=1
rarity=4
exp=3
```

Limits: `coin` 1–20, `disk` 1–10, `rarity` 1–20, `exp` 1–20. `status.txt` next to it shows what is currently active.

## Uninstall

Delete `ue4ss\Mods\MetalTweaks`. To remove UE4SS too, delete `dwmapi.dll` and the `ue4ss` folder from `Binaries\Win64`.

## Notes

- Don't stack this with another D.Chip multiplier (for example a Cheat Engine table); both would multiply.
- A single D.Chip gain larger than 1000 is not multiplied, so loading a save or switching scenes doesn't inflate your balance.
- Extra disks spawn where the original disk dropped. The game's item pool size is unknown, so very high disk multipliers may leave some extras unspawned.
- If something fails, the window's "Last:" line and `ue4ss\UE4SS.log` show the `[MetalTweaks]` error. Please include it in bug reports.

## Disclaimer

Fan-made and unofficial. Not affiliated with or endorsed by ALPHAWING Inc. or PLAYISM. This repository contains no game code or assets. Use at your own risk, and consider backing up your save first. If the rights holders ask for this to be removed, it will be.

## 中文说明

非官方的 Metal Bringer UE4SS mod，带设置窗口，所有选项默认 x1（关闭），改了约 1 秒生效：D.Chip 获取倍率、Disk 掉落数量倍率、R4/R5 稀有度权重、EXP 获取倍率。

安装：先装 UE4SS **experimental** 版（解压到 `Binaries\Win64`），再把 `MetalTweaks` 文件夹放进 `ue4ss\Mods\`，启动游戏后双击 `MetalTweaksPanel.cmd` 打开设置窗口（需要 Python 3；没有的话可以直接改 `settings.txt`）。窗口右下角可切换中文。不要和 CT 表的 D.Chip 倍率同时使用。

## License

MIT, see [LICENSE](LICENSE).
