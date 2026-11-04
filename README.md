# Tank-Full Smart Dehumidifier Controller

FPGA-based dehumidifier control logic for the Digital System Design (EE311) project. The RTL targets the Digilent Basys 3 board and demonstrates humidity hysteresis, tank-full protection, defrost/recovery sequencing, button debouncing, a seven-segment display, and LED status outputs.

> **Demonstrator scope:** The current design has no physical humidity or tank sensor. The Basys 3 buttons simulate the humidity value and tank status. `compressor_on` and `fan_on` are internal logic signals displayed on LEDs; they are not connected to appliance loads or relay drivers.

![Basys 3 project demonstration](<Working_pic.jpeg>)

## Features

- Five synchronized and debounced push-button inputs.
- Humidity value adjusted in 5% steps from 0% to 100%.
- Hysteresis: demand sets at 60% and clears at 50% by default.
- Tank status cycles through Normal, Low, and Full; Full disables the modeled compressor and fan outputs.
- Defrost request with a five-second recovery interval by default.
- Three-minute minimum compressor off-time by default.
- Latched fault handling for an invalid tank-status encoding.
- Multiplexed four-digit seven-segment display and 15 mapped status LEDs.

## Design overview

The controller's main states are `IDLE`, `DEHUMIDIFY`, `DEFROST`, `RECOVERY`, `TANK_FULL`, and `FAULT`. Invalid tank status has highest fault priority; a full tank and a defrost request also override normal humidity demand. A reset clears the fault latch and returns the control logic to its initialized state.

At the Basys 3 100 MHz clock, the default parameters correspond to:

| Parameter | Default | Meaning |
|---|---:|---|
| `DEBOUNCE_CYCLES` | 1,000,000 cycles | 10 ms stable input filter |
| `HUMIDITY_ON` / `HUMIDITY_OFF` | 60% / 50% | Hysteresis thresholds |
| `MIN_OFF_CYCLES` | 18,000,000,000 cycles | 180 s compressor minimum off-time |
| `RECOVERY_CYCLES` | 500,000,000 cycles | 5 s post-defrost recovery |
| `DIGIT_REFRESH_CYCLES` | 25,000 cycles | 250 µs per digit; about 1 kHz full display scan |

### Button mapping

| Basys 3 button | Function |
|---|---|
| `btnC` | Reset |
| `btnU` | Increase displayed/demo humidity by 5% |
| `btnD` | Decrease displayed/demo humidity by 5% |
| `btnL` | Cycle tank status: Normal → Low → Full → Normal |
| `btnR` | Toggle defrost request |

### LED mapping

| LED bit | Meaning |
|---:|---|
| `led[6:0]` | Binary humidity value |
| `led[7]` | Modeled compressor output |
| `led[8]` | Modeled fan output |
| `led[9]` | Dehumidify state |
| `led[10]` | Defrost state |
| `led[11]` | Tank Full status |
| `led[12]` | Latched fault |
| `led[13]` | Tank Low status |
| `led[14]` | Anti-cycle lockout active |

The seven-segment display shows the humidity value from 000 to 100. Segment and digit-enable pins are active-low, as configured for the Basys 3 display.

## Source tree

```text
.
├── rtl/
│   ├── top_controller.v
│   ├── dehumidifier_controller.v
│   ├── humidity_controller.v
│   ├── tank_controller.v
│   ├── button_debouncer.v
│   ├── seven_segment_display.v
│   └── led_status_display.v
├── tb/
│   └── tb_top_controller.v
├── basys3_controller.xdc
├── report.tex
├── README.md
└── report evidence images and demo video
```

## Build and simulate

### Icarus Verilog

From the project root, compile and run the self-checking testbench:

```sh
iverilog -g2005 -s tb_top_controller -o sim.out \
  rtl/button_debouncer.v \
  rtl/dehumidifier_controller.v \
  rtl/humidity_controller.v \
  rtl/led_status_display.v \
  rtl/seven_segment_display.v \
  rtl/tank_controller.v \
  rtl/top_controller.v \
  tb/tb_top_controller.v
vvp sim.out
```

The testbench overrides long real-time counters with short simulation values. It exercises reset, debounce behavior, humidity adjustment and hysteresis, lockout, tank-full shutdown, defrost/recovery, invalid-state fault handling, display digits, and LED status. The simulator prints a PASS/FAIL summary at completion.

### AMD Vivado

1. Create an RTL project and select **Basys 3 / `xc7a35tcpg236-1`**.
2. Add all files in `rtl/` as design sources and set `top_controller` as the top module.
3. Add `basys3_controller.xdc` as the constraints file. Add `tb/tb_top_controller.v` as a simulation source.
4. Run simulation, synthesis, implementation, and bitstream generation. Program the Basys 3 through Hardware Manager.

The provided XDC sets the 100 MHz clock and maps the buttons, LEDs, seven-segment segments, and anodes. A physical dehumidifier, humidity sensor, tank sensor, relay, and mains interface are outside this demonstrator's scope.

## Report and evidence

The academic report source is [`report.tex`](report.tex). It uses the supplied cover-page details and includes the requested circuit/schematic, methodology flowchart, FSM, relevant timing diagram, and photographs of the implemented Basys 3 demonstration.

Compile the report from the project root with a LaTeX distribution (run twice to populate the table of contents):

```sh
pdflatex report.tex
pdflatex report.tex
```

If `nitk_logo.jpg` is added to the project root, the report uses it on the cover; otherwise, it renders a labeled placeholder.

| Report evidence | File |
|---|---|
| Circuit / synthesized schematic | [`Schematic.png`](Schematic.png) |
| Methodology flowchart | [`Tank-Full Dehumidifier Control Flowchart.png`](<Tank-Full Dehumidifier Control Flowchart.png>) |
| FSM diagram | [`Dehumidifier Controller FSM Diagram.png`](<Dehumidifier Controller FSM Diagram.png>) |
| Timing diagram | [`Basys 3 Dehumidifier Timing Diagram.png`](<Basys 3 Dehumidifier Timing Diagram.png>) |
| Hardware photographs | [`Working_pic.jpeg`](Working_pic.jpeg), [`basys3_hardware_walkaround.png`](basys3_hardware_walkaround.png) |
| Simulation waveform | [`Simulation_waveform.png`](Simulation_waveform.png) |
| Vivado resource and timing reports | [`Utilisation_Report.png`](Utilisation_Report.png), [`Timing_Reports.png`](Timing_Reports.png) |

The flowchart is a conceptual methodology illustration. Where it refers to sensor readings, the current RTL uses the button-controlled demo value and tank state described above.

## Future scope

The files marked `(further)` are future-work references and are not evidence of completed RTL features:

- **On-chip logic analysis:** [`Debug_ILA(further).png`](<Debug_ILA(further).png>) shows the Vivado ILA setup wizard. A future revision can instantiate an ILA and capture FSM state, humidity demand, tank state, anti-cycle lockout, and modeled outputs during operation.
- **Vivado IP exploration:** [`IP_Catalog(further).png`](<IP_Catalog(further).png>) is retained as a design-view reference for further Vivado/IP exploration. A future revision can evaluate suitable catalog IP and document any integration into the design.
- Add real humidity and tank-level sensors with appropriate input conditioning and calibration.
- Add isolated driver circuitry and a safe, rated interface before controlling real compressor or fan hardware.
- Add configurable thresholds, persistent settings, and further fault-detection cases.

## GitHub note

`Demo_video.mp4` is about 195 MB, above GitHub's 100 MiB limit for ordinary Git files ([GitHub large-file documentation](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)). This project marks it for Git LFS in `.gitattributes`; create an empty GitHub repository, then from this directory run the following (replace `YOUR_GITHUB_REMOTE` with its URL):

```sh
git init
git lfs install
git add .
git commit -m "Add dehumidifier controller project"
git branch -M main
git remote add origin YOUR_GITHUB_REMOTE
git push -u origin main
```

If Git LFS is unavailable, omit the video from the repository and host it separately. Vivado run products, bitstreams, and simulator outputs are excluded by `.gitignore`.
