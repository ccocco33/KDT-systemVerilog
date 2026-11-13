# Verilog 시험 정리 (11/10 시험)

> 범위: `daily_log`, `daily_projects` (2026.09.30 ~ 10.29)
> 구성: **Part 1 개념 정리** → **Part 2 설계 가이드 O/X** → **Part 3 예상 문제 + 답안** → **Part 4 시험 직전 한 장 요약**

| # | 시험 주제 | 관련 수업/프로젝트 |
|---|---|---|
| 1 | MUX, Decoder, Counter, tick_gen (조합/순차) | 10/01 fnd_controller, 10/07 counter_10000, 10/14 stopwatch |
| 2 | Synchronizer, F/F, SIPO, PISO | 10/08, 10/12, 10/13 debounce, 10/15 uart_tx, 10/20 uart_rx |
| 3 | FSM, 패턴 검출기 | 10/08 led_fsm, 10/12 mealy/moore 0101 |
| 4 | 설계 가이드, Latch | 10/02, 10/12, interview/10.13 (교재 코딩 가이드) |
| 5 | Blocking / Non-blocking, Race condition | 10/07, 10/12, 10/21 |
| 6 | Reset | 10/06_2, 10/07, 10/15 |
| 7 | CDC | 10/08, 10/28 |
| 8 | UART 프로토콜 | 10/15, 10/20, 10/23, 10/27 |

---

# Part 1. 개념 정리

## 1. 조합 논리(CL) vs 순차 논리(SL)

| 구분 | 조합 논리 (Combinational) | 순차 논리 (Sequential) |
|---|---|---|
| 출력 결정 | **현재 입력만** | 현재 입력 + **이전 상태(기억)** |
| 저장 소자 | 없음 | 있음 (F/F, Latch) |
| 클럭 | 불필요 | 필요 (동기식) |
| 예 | **MUX, Decoder**, Encoder, 가산기, 비교기, BCD→7seg | **Counter, tick_gen**, 레지스터, 시프트 레지스터, FSM 상태 레지스터 |
| Verilog | `assign`, `always @(*)` + `=` | `always @(posedge clk)` + `<=` |
| 주의 | 모든 경로에 출력 할당 안 하면 **Latch** | reset 필수, `<=` 사용 |

- 조합 회로는 "클럭에 비동기적으로 동작"하고 저장 소자를 포함하지 않는다. (교재 정의)
- **조합 always 안에서 자기 자신을 갱신**(`cnt = cnt + 1`)하면 **조합 루프** → 값을 세거나 기억하는 건 반드시 순차 블록에서.

### 1.1 MUX (Multiplexer) — 조합
- 여러 입력 중 **sel 신호로 하나를 선택**해서 출력
- n개 입력 → sel 비트 수 = `$clog2(n)`

```verilog
// 2x1 MUX : 3항 연산자
assign y = sel ? in1 : in0;

// 4x1 MUX : case (fnd_controller의 mux_4x1)
always @(*) begin
    case (sel)
        2'b00: y = in0;
        2'b01: y = in1;
        2'b10: y = in2;
        2'b11: y = in3;
        default: y = 4'b0;   // latch 방지
    endcase
end
```

| if-else 체인 | case |
|---|---|
| **우선순위 있음** (위쪽 조건일수록 높음) | 모든 항목이 **동등** (병렬) |
| 합성 → **MUX가 직렬로 연결된 체인** (처음 조건이 출력에 가장 가까운 MUX) | 합성 → 하나의 **병렬 MUX** |
| 우선순위 인코더 등에 사용 | 디코더, FSM, 일반 MUX |

### 1.2 Decoder — 조합
- n비트 입력 → 2ⁿ개 출력 중 **하나만 활성화**
- FND `decoder_2x4`: 자리 선택(`fnd_com`), **Active-Low** (0이면 그 자리 ON)

| sel | fnd_com |
|---|---|
| 00 | 1110 |
| 01 | 1101 |
| 10 | 1011 |
| 11 | 0111 |

```verilog
always @(*) begin
    case (sel)
        2'b00: fnd_com = 4'b1110;
        2'b01: fnd_com = 4'b1101;
        2'b10: fnd_com = 4'b1011;
        2'b11: fnd_com = 4'b0111;
        default: fnd_com = 4'b1111;
    endcase
end
```
- **BCD → 7-seg 디코더**(bcd 모듈): 4bit 숫자 → 폰트 `{dp,g,f,e,d,c,b,a}`, Active-Low
  - `0 → 8'hC0`, `8 → 8'h80`, 전부 끔 → `8'hFF`, dp만 켬 → `8'h7F`
- 디코더/비교기 출력은 **글리치가 많음** → 이 출력으로 clock, reset, latch enable 직접 구동 금지

### 1.3 FND 시분할(Dynamic Display) 구조
```
clk(100MHz) → [clk_div / tick] → [counter_4] → sel(2bit)
                                     ├→ [decoder_2x4] → fnd_com  (어느 자리)
fnd_data → [digit_splitter] → [mux_4x1] → [bcd] → fnd_font      (무슨 숫자)
```
| 블록 | 종류 |
|---|---|
| clk_div / tick_gen, counter_4 | **순차** |
| decoder_2x4, digit_splitter(`%`, `/`), mux_4x1, bcd | **조합** |
- 세그먼트 선을 4자리가 **공유** → 한 순간 한 자리만 → 빠르게 돌려 **잔상 효과**
- 자리(com)와 숫자(font)를 **같은 sel**로 동시에 바꿔야 함
- 800Hz 스캔 → 자리당 200Hz

### 1.4 Counter — 순차
- 클럭(또는 tick)마다 증가/감소
- **동기식 카운터**: 모든 FF가 같은 클럭 → 설계·검증 쉬움, 빠름 (실무 표준)
- **비동기식(리플) 카운터**: FF 출력이 다음 FF 클럭 → 지연 누적, 타이밍 분석 어려움 → 잘 안 씀
- 비트 폭 = `$clog2(최대값+1)` → 0~9999 → **14bit**, 0~59 → 6bit, 0~99 → 7bit, 0~23 → 5bit

```verilog
// 0~9999 up/down 카운터 (tick일 때만 동작)
always @(posedge clk, posedge reset) begin
    if (reset)          counter_reg <= 0;
    else if (clear)     counter_reg <= 0;
    else if (i_tick) begin
        if (up_down) begin                       // down
            counter_reg <= counter_reg - 1;
            if (counter_reg == 0) counter_reg <= 9999;
        end else begin                           // up
            counter_reg <= counter_reg + 1;
            if (counter_reg == 9999) counter_reg <= 0;
        end
    end
end
```
- non-blocking에서 같은 변수에 여러 번 할당 → **마지막 할당이 적용** (기본 동작 후 경계 조건으로 덮어쓰는 패턴)
- 2ⁿ 카운터는 오버플로로 자동 순환 (counter_4: 2bit → 0,1,2,3,0...)
- **캐스케이드 카운터**(스톱워치): msec(0~99) → sec(0~59) → min(0~59) → hour(0~23), 아랫단이 한 바퀴 돌 때 `o_tick` 1클럭 → 윗단 `i_tick`

### 1.5 tick_gen — 순차 (Clock Enable 방식)
- **N클럭마다 1클럭 폭의 펄스(tick)** 를 만드는 회로. 클럭은 그대로 두고 enable로 쓴다.

```verilog
module tick_gen #(parameter F_COUNT = 10_000_000) (   // 100MHz / 10M = 10Hz
    input clk, reset,
    output reg o_tick
);
    reg [$clog2(F_COUNT)-1:0] counter_reg;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            o_tick      <= 1'b0;
        end else if (counter_reg == F_COUNT - 1) begin
            counter_reg <= 0;
            o_tick      <= 1'b1;      // 딱 1클럭만 1
        end else begin
            counter_reg <= counter_reg + 1;
            o_tick      <= 1'b0;      // 반드시 0으로 되돌림
        end
    end
endmodule
```

| 목적 | F_COUNT (100MHz 기준) | 카운터 비트 |
|---|---|---|
| 10Hz (0.1s) | 10,000,000 | 24 |
| 100Hz (10ms, 스톱워치) | 1,000,000 | 20 |
| 1kHz (1ms) | 100,000 | 17 |
| 1MHz (1µs, SR04/debounce) | 100 | 7 |
| UART 9600bps | 10,416 | 14 |
| UART 9600 × 16 (오버샘플) | 651 | 10 |

- **분주 클럭 vs tick** (자주 나옴!)

| | 분주 클럭 (토글 방식) | tick (enable 방식) |
|---|---|---|
| 출력 | duty 50% 클럭 | 1클럭 폭 펄스 |
| 비교값 | 반주기 `N/2 - 1`에서 토글 | `N - 1`에서 1클럭 |
| 사용 | `always @(posedge clk_div)` | `always @(posedge clk) if (tick)` |
| 문제 | 로직 클럭 → 글로벌 클럭망 못 탐 → **skew**, 클럭 도메인이 여러 개 → CDC 유사 문제, STA 복잡 | 클럭 도메인 **1개** → 안전 |
- 결론: **FPGA에서는 tick(enable) 방식이 정석**, 진짜 다른 클럭이 필요하면 PLL/MMCM.
- tick 설계 체크 포인트: **모든 경로에서 tick을 0으로 되돌리는가?** (run_stop으로 멈출 때 tick이 1로 고정되는 버그 주의)

---

## 2. Latch vs Flip-Flop

| 구분 | D Latch | D Flip-Flop |
|---|---|---|
| 동작 | **레벨 트리거**: en(clk)=1인 동안 D가 Q로 그대로 통과(transparent), 0이면 유지 | **엣지 트리거**: 클럭 상승(하강) 순간에만 D 샘플링 |
| 구조 | 게이트 몇 개 | 래치 2개 (master-slave: negative latch → positive latch) |
| 타이밍 분석 | 어려움 (time borrowing) | 쉬움 → **동기 설계의 기본 소자** |
| 코드 | `always @(*) if (en) q = d;` | `always @(posedge clk) q <= d;` |

```verilog
// D Latch (positive) — 의도적으로 만들 때의 모델링
always @(*)
    if (en) q = d;            // en=0일 때 할당이 없음 → 이전 값 유지 → latch

// D F/F + 비동기 리셋
always @(posedge clk or negedge rst_n)
    if (!rst_n) q <= 1'b0;
    else        q <= d;

// D F/F + 동기 리셋
always @(posedge clk)
    if (!rst_n) q <= 1'b0;
    else        q <= d;
```

### 2.1 F/F 타이밍 파라미터
- **Setup time**: 클럭 엣지 **전** D가 안정돼야 하는 최소 시간
- **Hold time**: 클럭 엣지 **후** D가 유지돼야 하는 최소 시간
- **Clock-to-Q**: 엣지 후 Q가 바뀌기까지 시간
- 위반 시 → **메타스테이빌리티**: Q가 0도 1도 아닌 중간 상태에 머물다가 랜덤하게 결정

**타이밍 공식**
- Setup: `Tclk ≥ tclk-q + tcomb(max) + tsu` → `fmax = 1 / (tclk-q + tcomb + tsu)`
  - 위반 시: 클럭 낮추기, **파이프라이닝**, 조합 논리 줄이기
- Hold: `tclk-q + tcomb(min) ≥ th`
  - 위반 시: 지연 버퍼 삽입 (**클럭을 낮춰도 해결 안 됨**)

### 2.2 F/F 장단점
- 장점: **글리치 제거**(엣지에서만 샘플링), 동기화 → STA 쉬움, 상태 저장, 파이프라이닝으로 주파수↑
- 단점: 출력이 클럭만큼 늦음(latency), 면적↑(래치 2개 분량), 클럭 토글로 전력·발열↑, skew/jitter 관리 필요

### 2.3 의도하지 않은 Latch ⭐
- **원인**: 조합 always 블록에서 **모든 경우에 출력이 할당되지 않음** → 이전 값을 기억해야 하니 합성기가 latch 생성
```verilog
// ❌ sel==2'b11 할당 없음 → latch
always @(*) case (sel) 2'b00: y=a; 2'b01: y=b; 2'b10: y=c; endcase
// ❌ else 없음 → latch
always @(*) if (en) y = d;
```
- **해결법 4가지**
  1. `case`에 **default**
  2. `if`에 **else**
  3. always 맨 위에 **기본값(초깃값) 할당** ← 가장 확실 (`n_state = c_state;`)
  4. 감도 리스트 `@(*)` 사용
- **왜 나쁜가**: STA 어려움, 글리치에 취약(글리치가 그대로 저장), DFT/스캔 테스트 어려움, 시뮬-합성 불일치
- 합성 로그 `Latch inferred` 경고는 반드시 확인
- `(* full_case *)`, `(* parallel_case *)`는 **공식 문법 아님**, 지원 안 하는 툴 있음 → 사용 주의

---

## 3. Shift Register / Synchronizer / SIPO / PISO

| 종류 | 입력 → 출력 | 용도 |
|---|---|---|
| **SISO** | 직렬 → 직렬 | 지연선, **Synchronizer** (CDC, 메타스테이블 확률↓) |
| **SIPO** | 직렬 → 병렬 | **Debounce**, 직렬 통신 **수신(UART RX)** |
| **PISO** | 병렬 → 직렬 | 직렬 통신 **송신(UART TX)** |
| **PIPO** | 병렬 → 병렬 | 데이터 레지스터 |
| LFSR | 피드백 | 난수, 카운터, CRC/체크섬, BIST |

### 3.1 2-FF Synchronizer (SISO의 응용)
```verilog
reg sync1, sync2;
always @(posedge clk or negedge rst_n)
    if (!rst_n) {sync2, sync1} <= 2'b00;
    else        {sync2, sync1} <= {sync1, async_in};
// sync2만 사용! sync1은 메타스테이블일 수 있음
```
- 메타스테이빌리티를 **없애는 게 아니라 확률을 낮춘다** (첫 FF가 메타스테이블해도 1클럭 동안 풀릴 시간)
- 두 FF 사이에 **조합 논리 금지** (해소 시간 감소)
- 송신 신호는 **FF 출력**이어야 함 (조합 출력이면 글리치까지 넘어감)
- **1bit 신호 전용**. 멀티비트에 각각 달면 안 됨 (→ CDC 참고)
- 고속이면 3단

### 3.2 SIPO
```verilog
// 왼쪽 시프트 (LSB로 입력) — MSB-first 프로토콜(SPI)
always @(posedge clk or negedge rst_n)
    if (!rst_n) q <= 4'b0;
    else        q <= {q[2:0], din};

// 오른쪽 시프트 (MSB로 입력) — LSB-first 프로토콜(UART RX)
data_next = {rx, data_reg[7:1]};   // 8번 시프트 후 처음 받은 비트가 [0]에
```
- 4bit SIPO: 4클럭 후 병렬 데이터 완성

**SIPO 응용: Debounce (8bit 시프트 + AND)**
```verilog
always @(posedge clk) if (tick_1mhz) q_reg <= {i_btn, q_reg[7:1]};  // SIPO
assign debounce = &q_reg;                         // 8번 연속 1이어야 1 (축약 AND)
always @(posedge clk) edge_reg <= debounce;
assign o_btn = debounce & ~edge_reg;              // 상승 엣지 → 1클럭 펄스
```
- 채터링(bounce): 기계식 스위치가 누르는 순간 수 ms 붙었다 떨어짐
- 안정 판단 시간 = 샘플 수 × 샘플 주기 (100MHz: 8×10ns=80ns → 너무 짧음 → 1MHz: 8µs)
- 역할 구분: **Synchronizer → 메타스테이빌리티 해결 / Debouncer → 채터링 해결**

| 엣지 검출 | 식 |
|---|---|
| 상승 | `cur & ~prev` |
| 하강 | `~cur & prev` |
| 양쪽 | `cur ^ prev` |

### 3.3 PISO
```verilog
always @(posedge clk or posedge rst) begin
    if (rst)        data_reg <= 8'h00;
    else if (load)  data_reg <= din;                    // 병렬 로드
    else if (shift) data_reg <= {1'b0, data_reg[7:1]};  // 오른쪽 시프트
end
assign sout = data_reg[0];                              // LSB first
```
- UART TX DATA 상태: `tx_next = data_reg[0]`, b_tick마다 `data_next = {1'b0, data_reg[7:1]}`
- IDLE에서 `tx_data`를 미리 레지스터에 저장 → 전송 중 입력이 바뀌어도 안전

---

## 4. Blocking (=) vs Non-blocking (<=) ⭐

| | Blocking `=` | Non-blocking `<=` |
|---|---|---|
| 실행 | 한 줄씩 **즉시** 계산 + **즉시** 좌변 갱신 | 우변 즉시 계산, **좌변 갱신은 타임스텝 끝(NBA 영역)** |
| 다음 문장 | 앞 문장이 끝나야 실행 (막는다) | 기다리지 않고 진행 |
| 순서 영향 | **있음** | **없음** (모두 동시에 갱신) |
| 용도 | **조합 논리** `always @(*)` | **순차 논리** `always @(posedge clk)` |

> ❗ Non-blocking은 "비동기"나 "딜레이"가 아니다. **같은 시간에 모든 우변을 먼저 읽고, 나중에 한꺼번에 갱신** → 같은 엣지에서 여러 FF가 동시에 바뀌는 하드웨어를 흉내 내는 것.

**예제 1: Swap**
```verilog
always @(posedge clk) begin a = b; b = a; end   // ❌ 둘 다 b
always @(posedge clk) begin a <= b; b <= a; end // ✅ 교환 (FF 2개)
```
**예제 2: 시프트 레지스터**
```verilog
always @(posedge clk) begin q1 <= d; q2 <= q1; q3 <= q2; end  // ✅ FF 3개, 3단 시프트
always @(posedge clk) begin q1 = d;  q2 = q1;  q3 = q2;  end  // ❌ d가 한 클럭에 q3까지 → FF 1개처럼
always @(posedge clk) begin q3 = q2; q2 = q1;  q1 = d;   end  // (역순이면 동작은 하지만 순서 의존 → 비권장)
```

### 4.1 이벤트 스케줄링 (한 타임스텝 내 순서)
```
Active   : blocking(=), assign, $display, NBA 우변 계산
Inactive : #0
NBA      : non-blocking(<=) 좌변 갱신
Monitor  : $strobe, $monitor
```
- `$display` = 즉시 출력 (NBA 반영 전 값) / `$strobe` = 타임스텝 끝 (최종 값) / `$monitor` = 값 바뀔 때마다

```verilog
initial begin
    a = 0;
    a <= 1;
    $display("%b", a);  // 0
    $strobe ("%b", a);  // 1
end
```

### 4.2 코딩 가이드 (교재 + Cummings) ⭐⭐
1. **순차 논리 → `<=`**
2. **조합 논리 → `=`**
3. **순차 + 조합이 한 블록에 섞이면 → `<=`**
4. **한 always 안에서 `=`와 `<=` 혼용 금지**
5. **같은 reg를 여러 always에서 할당 금지** (multiple driven)
6. `<=` 결과 확인은 `$strobe`
7. `#0` 지연 사용 금지

---

## 5. Race Condition ⭐

**정의**: 같은 시뮬레이션 시간에 실행되는 여러 블록/문장의 **실행 순서가 정해져 있지 않아서** 시뮬레이터(또는 실행)마다 결과가 달라지는 현상.

```verilog
// ❌ 레이스: 어느 always가 먼저냐에 따라 b가 새 a 또는 이전 a
always @(posedge clk) a = d;
always @(posedge clk) b = a;

// ✅ 해결: non-blocking → b는 항상 이전 a (FF 2개 직렬)
always @(posedge clk) a <= d;
always @(posedge clk) b <= a;
```

**테스트벤치 레이스**
- 클럭 엣지와 **같은 시간에 입력을 바꾸면** DUT FF가 바뀌기 전/후 값 중 무엇을 읽을지 불확정
- 해결: `@(posedge clk); #1;` 처럼 엣지에서 비켜서 입력 변경, 또는 **`@(negedge clk)`에서 입력 변경** (반 주기 여유)

**발생 원인 정리**
| 원인 | 해결 |
|---|---|
| 순차 블록에서 blocking 사용 | `<=` 사용 |
| 같은 변수를 여러 always에서 할당 | 한 블록에서만 할당 |
| TB에서 엣지와 동시에 자극 | negedge / `#1` 오프셋 |
| `$display`로 `<=` 값 확인 | `$strobe` |

---

## 6. Reset ⭐

### 6.1 동기 리셋 vs 비동기 리셋
```verilog
// 비동기 리셋: 감도 리스트에 reset 포함
always @(posedge clk or posedge rst)
    if (rst) q <= 0; else q <= d;

// 동기 리셋: 감도 리스트에 clk만
always @(posedge clk)
    if (rst) q <= 0; else q <= d;
```

| | 동기 리셋 | 비동기 리셋 |
|---|---|---|
| 동작 시점 | 클럭 엣지에서만 | **즉시** (클럭 없어도) |
| 장점 | 글리치에 강함, 타이밍 분석 쉬움, 완전 동기 설계 | 클럭 없이도 리셋, 데이터 경로에 로직 추가 없음, 빠름 |
| 단점 | 클럭이 있어야 함, 리셋 펄스가 1클럭 이상이어야 함, D 앞에 로직 추가 | **해제(deassert)가 클럭 엣지와 겹치면 메타스테이블** (recovery/removal 위반), 글리치에 민감 |
| 수업 메모 | **칩(ASIC)에서 많이 씀** | **FPGA에서 많이 씀** |

### 6.2 Reset Synchronizer — 비동기 assert, 동기 deassert
```verilog
reg r1, r2;
always @(posedge clk or negedge rst_n_in)
    if (!rst_n_in) {r2, r1} <= 2'b00;          // 리셋 걸림: 즉시(비동기)
    else           {r2, r1} <= {r1, 1'b1};     // 리셋 풀림: 2클럭 후 클럭에 맞춰(동기)
assign rst_n = r2;
```
- 걸 때는 즉시, 풀 때는 클럭에 맞춰서 → 두 방식의 장점만 사용

### 6.3 왜 Negative(Active-Low) 리셋(`rst_n`)을 많이 쓰나? (10/06 질문)
- 전원 인가 직후 신호가 0(Low)에서 시작 → **파워온 시 자연스럽게 리셋 상태** 유지
- 평소 High(풀업)로 유지 → 노이즈로 순간 Low가 되기보다 안정적, **노이즈에 강함**
- 전통적으로 CMOS/TTL에서 풀업 + Low 구동이 유리 (오픈 드레인/와이어드-AND로 여러 소스가 리셋 가능)
- 네이밍: active-low는 `_n` 접미사 (`rst_n`)
- 참고: Basys3 버튼은 누르면 1 → 수업 코드는 `posedge reset` (active-high)

### 6.4 Reset 설계 주의
- **FSM은 비동기 리셋을 갖도록 설계** (교재 가이드)
- 리셋 시 출력값도 의미 있게: UART `tx_reg <= 1'b1` (idle=High, 0이 나가면 상대가 start bit로 오해)
- **메모리(RAM)는 리셋이 없다** (수백 칸을 한 번에 지우는 하드웨어 없음)
- `if (reset | clear)` 처럼 비동기 리셋에 다른 신호를 OR → **글리치가 리셋 핀으로** → `if (reset) ... else if (clear) ...` 로 분리
- 조합 출력(디코더, 비교기)으로 리셋 구동 금지

---

## 7. CDC (Clock Domain Crossing) ⭐ 면접 필수

**정의**: 한 클럭 도메인에서 만든 신호를 **다른 클럭 도메인의 FF가 샘플링**하는 것. 위상 관계를 모르면 setup/hold 위반 → 메타스테이빌리티.

### 7.1 분류
```
동일 clock source ─┬─ 동일 phase ─────────→ CDC 아님
                   └─ phase 다름 ─────────→ (부분적) CDC
다른 clock source ─┬─ 같은 주파수, phase 다름 → CDC
                   └─ 다른 주파수 ─┬─ 빠름 → 느림 : 데이터 놓침(loss)
                                   └─ 느림 → 빠름 : 메타스테이블 확률↑
```
- 칩 ↔ 칩 통신 = 결국 CDC (UART, SPI, I2C)
- **외부 입력(버튼, 스위치, SR04 echo, UART rx)** 도 비동기 → CDC 환경 → synchronizer 필수

### 7.2 해결 방법
| 방법 | 대상 | 특징 |
|---|---|---|
| **2-FF Synchronizer** | 1bit 레벨 | 가장 기본, I/O |
| Pulse(Toggle) Synchronizer | 1bit 펄스 | 펄스 → 토글 → 동기화 → 엣지 검출 |
| **비동기 FIFO** | 멀티비트 연속 데이터 | **Gray 코드 포인터**를 2-FF로 동기화 |
| **MCP / Handshake** | 멀티비트, 가끔 | req/ack 1bit만 동기화, 데이터는 고정 유지 |

- **멀티비트에 2-FF를 각각 달면 안 되는 이유**: 비트마다 지연이 달라 `0111→1000` 변화 중 `1111`, `0000` 같은 엉뚱한 값을 읽음 (coherency 깨짐) → Gray 코드(1비트만 변함)/FIFO/handshake
- 동기 FIFO(같은 클럭) = 속도 차이 흡수 **버퍼** / 비동기 FIFO(다른 클럭) = **CDC 해결용**
- **MTBF** = `e^(tr/τ) / (T0 · f_clk · f_data)` → 단수를 늘리면 tr↑ → MTBF **지수적** 증가
- **tick을 쓰는 이유(10/28)**: tick일 때만 읽으면 판단 순간이 줄어 오류 확률 감소. 하지만 **synchronizer를 대신할 수는 없다** (CDC 환경에선 synchronizer 필수)

> **답변 템플릿**: "CDC는 비동기 클럭 도메인 간 신호 전달 시 setup/hold 위반으로 메타스테이빌리티가 생기는 문제입니다. 1bit는 2-FF synchronizer로 MTBF를 높이고, 펄스는 toggle synchronizer, 멀티비트는 비트 간 skew 때문에 각각 동기화하면 안 되므로 연속 데이터는 Gray 코드 포인터의 비동기 FIFO, 간헐적 데이터는 req/ack handshake를 씁니다."

---

## 8. FSM (Finite State Machine) ⭐

### 8.1 구조 (피드백 구조)
```
input ──→ [Next State Logic (CL)] ──→ [State Register (SL)] ──┬──→ [Output Logic (CL)] ──→ output
              ↑                                               │
              └──────────── current state (feedback) ─────────┘
```
- 디지털 설계 = **Datapath**(저장·연산: 카운터, 레지스터, MUX) + **Control**(FSM: 언제 무엇을)

### 8.2 Moore vs Mealy
| | Moore | Mealy |
|---|---|---|
| 출력 | **현재 상태만** | 현재 상태 + **현재 입력** |
| 반응 | 1클럭 늦음 | 입력에 즉시 |
| 상태 수 | 많음 | 적음 |
| 글리치 | 안정적 | 입력 글리치가 출력으로 전달 가능 |

### 8.3 FSM 코딩 스타일 (교재 가이드)
- **비동기 리셋**을 갖도록
- **next state logic / state register / output logic** 을 분리된 always(또는 assign)로
- **full case** 처리 (default)
- 상태 코드는 **localparam** (외부에서 못 바꾸게)
- 복잡하지 않게
- 조합 블록 맨 위에 `n_state = c_state;` 기본값 → latch 방지

```verilog
localparam S0=2'd0, S1=2'd1, S2=2'd2;
reg [1:0] c_state, n_state;

// ① State register (순차, <=)
always @(posedge clk or posedge rst)
    if (rst) c_state <= S0;
    else     c_state <= n_state;

// ② Next state logic (조합, =)
always @(*) begin
    n_state = c_state;          // 기본값
    case (c_state)
        S0: if (in) n_state = S1;
        S1: ...
        default: n_state = S0;
    endcase
end

// ③ Output logic (Moore: 상태만)
assign out = (c_state == S2);
```

**`_reg / _next` 패턴 (UART TX/RX, control_unit)**
- 상태뿐 아니라 FSM이 기억할 값(bit_cnt, data, tx, mode)도 `_reg`(순차 저장) / `_next`(조합 계산)로 분리
- 출력을 **레지스터 출력**으로 → 글리치 없음 (UART tx 글리치 = 가짜 start bit). 대가: 1클럭 지연

### 8.4 상태 인코딩
| 방식 | FF 수 | 특징 |
|---|---|---|
| Binary | `$clog2(N)` | FF 최소 |
| Gray | `$clog2(N)` | 순차 전이 시 1비트만 토글 → 저전력 |
| One-hot | N | 디코딩 간단·빠름 → **FPGA 선호** |

### 8.5 FSM 설계 체크
- 외부 입력을 기다리는 상태에는 **timeout(탈출 조건)** (SR04 WAIT/DISTANCE)
- 1클럭만 머무는 상태(CLEAR, MODE) → 1클럭 제어 펄스 생성
- 검증: **모든 상태(state coverage) + 모든 전이(transition coverage)** 를 지나가게
- ASM(Algorithm State Machine) 차트: FSM 설계 방법 중 하나

---

## 9. 패턴 검출기 (Sequence Detector) ⭐

### 9.1 상태 설계 원리
- 상태 = **"지금까지 맞게 들어온 패턴의 앞부분"**
- 실패 시 돌아갈 상태 = **지금까지 들어온 입력의 끝부분 중 패턴의 앞부분과 가장 길게 일치하는 것**
- **Non-overlap**: 검출 후 처음(S0)부터 / **Overlap**: 검출된 패턴의 끝을 다음 패턴의 앞으로 재사용

### 9.2 "0101" 검출기 — Mealy (S0~S3, 4상태)
| 현재 | 의미 | din=0 | din=1 |
|---|---|---|---|
| S0 | 없음 | S1 | S0 |
| S1 | `0` | S1 | S2 |
| S2 | `01` | S3 | S0 (`011` 겹침 없음) |
| S3 | `010` | S1 (`0100`→`0`) | **출력 1** → Non-overlap: **S0** / Overlap: **S2** (`0101`의 끝 `01`) |

### 9.3 "0101" 검출기 — Moore (S0~S4, 5상태)
| 현재 | 의미 | 출력 | din=0 | din=1 |
|---|---|---|---|---|
| S0 | 없음 | 0 | S1 | S0 |
| S1 | `0` | 0 | S1 | S2 |
| S2 | `01` | 0 | S3 | S0 |
| S3 | `010` | 0 | S1 | S4 |
| S4 | `0101` | **1** | Non-overlap: S1 / Overlap: **S3** (`01010`→`010`) | S0 |

- Mealy: 마지막 비트가 들어온 **그 클럭**에 출력 / Moore: 상태가 S4로 바뀐 **다음 클럭**에 출력 (1클럭 늦음)
- 입력 `01010101` → Overlap 3회, Non-overlap 2회

### 9.4 "101" 검출기 — Moore, Overlap (10/08 예제)
| 현재 | 의미 | 출력 | din=0 | din=1 |
|---|---|---|---|---|
| S0 | 없음 | 0 | S0 | S1 |
| S1 | `1` | 0 | S2 | S1 |
| S2 | `10` | 0 | S0 | S3 |
| S3 | `101` | **1** | S2 (`1010`→`10`) | S1 (`1011`→`1`) |

---

## 10. UART 프로토콜 ⭐

### 10.1 직렬 vs 병렬, 동기 vs 비동기
| 직렬 (Serial) | 병렬 (Parallel) |
|---|---|
| 1 line, 선 적음, 속도 느림, TX/RX 로직 복잡, **장거리 유리** | 여러 line, 빠름, **skew·crosstalk**, 로직 단순, 단거리 |
| UART(RS232), SPI, I²C, USB | 메모리 버스 |

- **UART = Universal Asynchronous Receiver/Transmitter** → **비동기식 (클럭선 없음)**, 송·수신이 각자 클럭으로 시간 측정
- SPI(SCLK), I²C(SCL)는 동기식 / USART = 동기 + 비동기
- Duplex: Full(동시 양방향, UART TX/RX 선 분리) / Half(한 번에 한 방향) / Simplex(단방향)

### 10.2 프레임 (9600-8-N-1)
```
 idle  start  D0  D1  D2  D3  D4  D5  D6  D7  stop  idle
 ‾‾‾‾‾|_____|‾‾‾X‾‾‾X‾‾‾X‾‾‾X‾‾‾X‾‾‾X‾‾‾X‾‾‾|‾‾‾‾‾‾‾‾‾‾‾
   1     0    ← LSB first ...........MSB →    1
```
| 항목 | 값 |
|---|---|
| Idle | **High(1)** |
| Start bit | **0** (1→0 하강으로 시작 감지) |
| Data | 8bit, **LSB first** (ASCII 1문자) |
| Parity | None (Even/Odd: 1의 개수를 짝/홀로 맞춤, 1bit 오류만 검출 가능, 짝수 개 오류는 못 잡음) |
| Stop bit | **1** (1bit) |
| 1 프레임 | **10bit** |
| Baud rate | 초당 비트 수, **TX/RX가 같아야 함** (2400, 9600, 19200, 115200 …) |

- 9600bps → 1bit = **104.17µs**, 1프레임 = 1.04ms → 최대 **960 byte/s**
- 예) `'0'`=`8'h30`=`0011_0000` → 선 위: `0(start) 0 0 0 0 1 1 0 0 1(stop)`

### 10.3 Baud tick
- TX만: `100_000_000 / 9600 = 10416` → 실제 9600.6bps (오차 0.006%)
- **16배 오버샘플링**: `100_000_000 / (9600*16) = 651` → 1bit = tick 16개
- 보레이트 오차 허용: 한 프레임 동안 누적 오차가 반 비트 미만 → 보통 **±2~3%**

### 10.4 UART TX FSM (PISO)
| 상태 | tx | 전이 |
|---|---|---|
| IDLE | 1 | `tx_start` → 데이터 저장, (WAIT) |
| WAIT | 1 | 다음 b_tick → START (start bit 길이 보장) |
| START | 0 | 1bit 시간 → DATA |
| DATA | `data_reg[0]` | 1bit마다 오른쪽 시프트, 8bit 후 STOP |
| STOP | 1 | 1bit 시간 → IDLE |
- `tx_busy`: 송신 중 1 / reset 시 `tx = 1`

### 10.5 UART RX FSM (SIPO + 가운데 샘플링)
| 상태 | 동작 | 전이 |
|---|---|---|
| IDLE | tick마다 rx 확인 | `rx == 0` → START |
| START | tick **8개**(반 비트) | `b_tick_cnt == 7` → DATA (start bit **가운데**) |
| DATA | tick **16개**마다 `data = {rx, data[7:1]}` | 8bit → STOP |
| STOP | tick 16개 | `rx_done = 1` (1클럭 펄스) → IDLE |
- **왜 반 비트(8 tick) 기다리나?** 비트 경계(엣지) 근처는 값이 변하는 중이라 불안정 → **가운데가 클럭 오차·지연에 가장 여유가 큼** → 이후 16 tick마다 = 매 비트의 가운데
- 카운터: b_tick_cnt 0~15 → 4bit, bit_cnt 0~7 → 3bit
- 개선: rx 앞단 **2-FF synchronizer**, false start 검출(START 가운데에서 rx=1이면 IDLE), framing error(STOP에서 rx=0)

### 10.6 Loopback / FIFO
- Loopback: `rx_done → tx_start`, `rx_data → tx_data` → 받은 문자를 그대로 echo → RX·TX 동시 검증
  - 한계: TX busy 중 다음 바이트가 오면 놓침 → **FIFO** 필요
- **동기 FIFO**: 원형 버퍼, wptr/rptr, full/empty, overflow(`we = push & ~full`)/underflow(`!empty`일 때만 pop) 방지, FWFT(조합 읽기)
- UART+FIFO 연결: 보내는 쪽 "데이터 있음(~empty)" + 받는 쪽 "받을 수 있음(~full, ~busy)" 둘 다 참일 때만 이동 (valid/ready)
- 레지스터 출력 상태 신호(`tx_busy`)는 **1클럭 늦게 반영** → pop 두 번 버그 주의

### 10.7 TB (task)
- `sender_uart`(Driver): rx에 start→8bit LSB first→stop 파형
- `receive_uart`(Monitor): `wait(~tx)` → 반 비트 → 8번 샘플 → stop 확인
- `score_board`: expected vs result, pass/fail 카운트 → **self-checking**
- task는 시간 제어(`#`, `@`, `wait`) 가능, function은 불가

---

## 11. 기타 자주 나오는 개념
- **Glitch**: 조합 논리에서 경로 지연 차이로 생기는 짧은 원치 않는 펄스 → FF를 통과시키면 제거
- **Propagation delay**: 입력 변화 → 출력 변화까지 시간 / Critical path: 가장 긴 조합 경로 → fmax 결정
- **Pipeline**: 긴 조합 중간에 레지스터 → throughput↑, latency↑, 면적↑ (feed-forward) / FSM은 feedback
- **Skew**: 같은 클럭이 FF마다 도착 시간이 다른 것 / **Jitter**: 엣지가 사이클마다 흔들림
- **CTS**: 클럭 트리 합성 → skew 최소화 / 조합 클럭 게이팅 금지 (`assign gclk = clk & en` ❌ → `if (en) q <= d` ✅)
- **4상태**: 0, 1, x(unknown: 미초기화, 충돌), z(high impedance: 구동 없음)
- 합성 불가 구문: `initial`, `#지연`, `forever`, `wait`, `fork-join`, `$display`, `force/release`, real
- `` `default_nettype none `` : 선언 안 한 신호를 암묵적 1bit wire로 만들지 않음 → 오타 검출
- 감도 리스트 누락 → **시뮬-합성 불일치** (합성기는 감도 리스트를 안 봄) → `@(*)`

---

# Part 2. 설계 가이드 — "이렇게 설계해도 되나요?" O/X

| # | 질문 | 답 | 이유 |
|---|---|---|---|
| 1 | 순차 always에서 `=`를 써도 되나? | ✗ | 레이스, 시프트 레지스터가 FF 1개로 합성되는 등 의도와 다른 회로 |
| 2 | 조합 always에서 `<=`를 써도 되나? | △(비권장) | 동작은 하나 시뮬 이벤트가 늘고 중간값 문제 → 조합은 `=` |
| 3 | 한 always 안에 `=`와 `<=` 섞어도 되나? | ✗ | 가이드 위반, 시뮬-합성 불일치 위험 |
| 4 | 같은 reg를 두 always에서 할당해도 되나? | ✗ | multiple driver, 레이스, 합성 에러 |
| 5 | 조합 always에서 if만 쓰고 else 생략해도 되나? | 기본값을 위에 줬으면 O / 아니면 ✗ | 할당 안 되는 경로 → latch |
| 6 | case에 default 안 넣어도 되나? | ✗(습관적으로 넣기) | latch, 정의 안 된 상태에서 탈출 경로 |
| 7 | 감도 리스트에 일부 신호만 적어도 되나? | ✗ | 시뮬-합성 불일치 → `@(*)` |
| 8 | 조합 always 안에서 `cnt = cnt + 1` 해도 되나? | ✗ | 조합 루프 → 순차 블록에서 |
| 9 | 분주한 신호를 다른 FF의 클럭으로 써도 되나? | ✗(FPGA) | 글로벌 클럭망 X, skew, 클럭 도메인 증가 → **tick(enable)** 또는 PLL |
| 10 | 조합 논리(디코더/비교기) 출력으로 clock·reset을 구동해도 되나? | ✗ | 글리치가 클럭/리셋으로 들어감 |
| 11 | `assign gclk = clk & en;` 클럭 게이팅 해도 되나? | ✗ | 글리치, CTS 어려움 → enable 사용 or 전용 ICG |
| 12 | 버튼/스위치 입력을 바로 FSM 조건에 써도 되나? | ✗ | 비동기 입력 → 메타스테이블 → synchronizer(+debounce) |
| 13 | 멀티비트 버스에 2-FF synchronizer를 비트별로 달아도 되나? | ✗ | 비트 간 skew로 잘못된 값 → Gray/FIFO/handshake |
| 14 | synchronizer의 첫 번째 FF 출력을 사용해도 되나? | ✗ | 메타스테이블 상태일 수 있음, 두 번째 FF 출력 사용 |
| 15 | 두 sync FF 사이에 조합 논리를 넣어도 되나? | ✗ | 메타스테이블 해소 시간 감소 |
| 16 | tick 사용하면 synchronizer 없어도 되나? | ✗ | 확률만 줄 뿐, CDC 환경에선 synchronizer 필수 |
| 17 | 래치를 사용해도 되나? | 의도한 경우만 △ / 의도치 않은 latch ✗ | STA 어려움, 글리치, DFT |
| 18 | 비동기 리셋 조건에 `reset \| clear`처럼 OR해도 되나? | ✗ | 글리치 리셋 → `if (reset) else if (clear)` |
| 19 | 비동기 리셋을 그냥 해제해도 되나? | △ | 해제가 클럭과 겹치면 메타스테이블 → **reset synchronizer**(비동기 assert, 동기 deassert) |
| 20 | RTL에 `#5` 지연을 넣으면 실제로 지연되나? | ✗ | 합성 시 무시, 시뮬 전용 |
| 21 | `initial`로 reg 초기화하면 합성되나? | ✗(원칙) | 합성 불가 구문 → reset으로 초기화 (FPGA 일부 툴만 지원) |
| 22 | FSM 상태 코드를 `parameter`로 해도 되나? | △ | 동작은 OK, 외부 변경 방지 위해 **localparam** 권장 |
| 23 | FSM이 외부 입력만 무한정 기다려도 되나? | ✗ | timeout 탈출 조건 필요 |
| 24 | UART tx를 조합 출력으로 내보내도 되나? | ✗(비권장) | 글리치 → 상대가 가짜 start bit로 인식 → 레지스터 출력 |
| 25 | tick 신호가 1클럭 이상 유지돼도 되나? | ✗ | 윗단 카운터가 매 클럭 증가 → 모든 경로에서 0으로 |
| 26 | 순차 로직 설계 시 reset 없이 해도 되나? | ✗(FF는 reset과 함께) | 초기값 x → 시뮬 x 전파, 동작 불확정 (단 RAM은 reset 없음) |
| 27 | TB에서 posedge와 동시에 입력을 바꿔도 되나? | ✗ | race → negedge 또는 `#1` |
| 28 | 포트 순서 연결 써도 되나? | △ | 가능하지만 순서 바뀌면 조용히 오류 → 이름 연결 |

### 순차 로직 설계 절차 (교재/수업 정리)
1. **사양 정하기**: 입력·출력, 동작 범위(최소·최대), 클럭 주파수
2. **블록 다이어그램**: Datapath(카운터, 레지스터, MUX) / Control(FSM) 분리
3. **비트 폭 계산**: `$clog2(최대값+1)`, tick의 F_COUNT 계산
4. **상태도/ASM 작성** (FSM이면): 상태, 전이 조건, 출력, timeout
5. **코딩 규칙**
   - 하나의 클럭, 모든 FF는 같은 엣지 (동기식)
   - 느린 동작은 tick(enable)
   - 순차 블록 `always @(posedge clk, posedge rst)` + `<=` + 리셋값
   - 조합 블록 `always @(*)` + `=` + 맨 위 기본값
   - `_reg / _next` 분리, 출력은 가능하면 레지스터 출력
   - 외부 비동기 입력 → synchronizer
6. **검증**: 경계값(0, MAX, wrap-around), 모든 상태/전이, 시뮬 시간 단축(파라미터 덮어쓰기), self-checking

---

# Part 3. 예상 문제 + 답안

> 답을 가리고 먼저 풀어보세요.

## A. 단답형 / 개념

**Q1.** 다음을 조합 논리 / 순차 논리로 분류하라: MUX, Decoder, Counter, tick_gen, BCD 디코더, digit_splitter, 시프트 레지스터, FSM의 next state logic
<details><summary>답</summary>

- 조합: MUX, Decoder, BCD 디코더, digit_splitter, FSM의 next state logic
- 순차: Counter, tick_gen, 시프트 레지스터
</details>

**Q2.** Latch와 Flip-Flop의 차이를 트리거 방식 중심으로 설명하라.
<details><summary>답</summary>

Latch는 **레벨 트리거**로 enable(clk)이 활성인 동안 입력이 출력으로 그대로 통과(transparent)하고, 비활성이면 값을 유지한다. F/F는 **엣지 트리거**로 클럭의 상승(또는 하강) 순간에만 입력을 샘플링한다. F/F는 master-slave 래치 2개로 구성되어 크지만 타이밍 분석이 쉬워 동기 설계의 기본 소자다.
</details>

**Q3.** 의도하지 않은 latch가 생기는 원인과 해결 방법 3가지 이상을 쓰라.
<details><summary>답</summary>

원인: 조합 always 블록에서 모든 입력 조건에 대해 출력이 할당되지 않으면 이전 값을 기억해야 해서 latch가 추론된다.
해결: ① case에 default ② if에 else ③ always 맨 위에 기본값 할당 ④ 감도 리스트 `@(*)`
</details>

**Q4.** Blocking과 Non-blocking의 차이를 쓰고 각각 어디에 사용하는지 쓰라.
<details><summary>답</summary>

Blocking(`=`)은 문장 순서대로 즉시 계산·즉시 갱신하여 순서가 결과에 영향을 준다 → 조합 논리. Non-blocking(`<=`)은 우변을 먼저 모두 계산하고 좌변 갱신을 타임스텝 끝(NBA 영역)에 한꺼번에 해서 순서에 무관 → 순차 논리.
</details>

**Q5.** Race condition이란 무엇이며 어떻게 방지하는가?
<details><summary>답</summary>

같은 시뮬레이션 시간에 실행되는 여러 블록의 실행 순서가 정해져 있지 않아 시뮬레이터/실행마다 결과가 달라지는 현상. 방지: 순차 논리는 `<=`, 같은 변수를 여러 always에서 할당하지 않기, 한 블록에서 `=`/`<=` 혼용 금지, TB에서는 클럭 엣지와 겹치지 않게(negedge 또는 `#1`) 자극을 준다.
</details>

**Q6.** 동기 리셋과 비동기 리셋의 차이와 장단점을 쓰라.
<details><summary>답</summary>

- 동기: 클럭 엣지에서만 리셋. 글리치에 강하고 타이밍 분석이 쉬움 / 클럭이 필요, 리셋이 1클럭 이상 유지돼야 함, D 앞 로직 추가
- 비동기: 클럭과 무관하게 즉시 리셋. 클럭 없이 리셋 가능, 데이터 경로 로직 없음 / 해제 시 클럭과 겹치면 메타스테이블, 글리치에 민감
- 해결: 비동기 assert, 동기 deassert (reset synchronizer)
</details>

**Q7.** Active-low(negative) 리셋을 많이 쓰는 이유는?
<details><summary>답</summary>

전원 인가 직후 Low에서 시작하므로 파워온 시 자연스럽게 리셋 상태가 되고, 평소 High(풀업)로 유지되어 노이즈에 강하다. 또한 여러 소스가 Low로 끌어내려 리셋을 거는 wired-AND 구성이 쉽다.
</details>

**Q8.** CDC란 무엇이고 해결 방법을 대상별로 쓰라.
<details><summary>답</summary>

서로 다른(위상 관계를 모르는) 클럭 도메인 사이에서 신호를 전달할 때 setup/hold 위반으로 메타스테이빌리티가 발생하는 문제. 1bit 레벨 → 2-FF synchronizer, 1bit 펄스 → toggle(pulse) synchronizer, 멀티비트 연속 데이터 → Gray 코드 포인터 비동기 FIFO, 멀티비트 간헐 데이터 → MCP/handshake(req/ack).
</details>

**Q9.** 멀티비트 신호에 2-FF synchronizer를 비트별로 달면 안 되는 이유는?
<details><summary>답</summary>

비트마다 경로 지연이 달라 값이 바뀌는 순간에 일부 비트만 새 값으로 샘플링될 수 있다. 예: `0111 → 1000` 중 `1111`이나 `0000`을 읽는다. 비트 각각은 동기화돼도 값 전체의 일관성이 깨진다. → Gray 코드, FIFO, handshake 사용.
</details>

**Q10.** Synchronizer와 Debouncer의 역할 차이는?
<details><summary>답</summary>

Synchronizer는 비동기 입력을 클럭 도메인으로 가져와 **메타스테이빌리티 확률**을 낮춘다. Debouncer는 기계식 스위치의 **채터링(바운스)** 을 걸러 일정 시간 안정된 값만 인정한다. Debouncer 앞단에 synchronizer를 포함시켜 설계한다.
</details>

**Q11.** SISO, SIPO, PISO, PIPO의 용도를 하나씩 쓰라.
<details><summary>답</summary>

SISO: synchronizer/지연선, SIPO: UART RX(직렬→병렬), debounce, PISO: UART TX(병렬→직렬), PIPO: 데이터 레지스터
</details>

**Q12.** Moore와 Mealy FSM의 차이 3가지를 쓰라.
<details><summary>답</summary>

① 출력: Moore는 현재 상태만, Mealy는 상태+입력 ② 반응: Moore는 1클럭 늦음, Mealy는 즉시 ③ 상태 수: Moore가 많음 (④ 글리치: Moore가 안정적, Mealy는 입력 글리치 전달 가능)
</details>

**Q13.** FSM 설계 시 교재 코딩 가이드를 쓰라.
<details><summary>답</summary>

비동기 리셋을 갖도록 설계, next state logic / state register / output logic을 분리된 always(assign)로 작성, full case(default) 처리, 복잡하지 않게, (상태 코드는 localparam, 조합 블록 기본값 할당).
</details>

**Q14.** 분주 클럭 대신 tick(clock enable)을 사용하는 이유는?
<details><summary>답</summary>

로직으로 만든 클럭은 글로벌 클럭 네트워크를 타지 못해 skew가 크고, 클럭 도메인이 늘어나 CDC 유사 문제와 STA 복잡도가 생긴다. tick 방식은 원래 클럭 하나만 쓰고 N클럭마다 1클럭 enable을 주므로 모든 FF가 한 클럭 도메인에 있어 안전하다.
</details>

**Q15.** UART 프레임 구성(9600-8-N-1)을 설명하라.
<details><summary>답</summary>

Idle은 High, Start bit 1개(0), Data 8bit LSB first, Parity 없음, Stop bit 1개(1). 1프레임 10bit, 9600bps이면 1bit ≈ 104.17µs. 비동기 방식이라 클럭선이 없고 송·수신 baud rate가 같아야 한다.
</details>

**Q16.** UART RX에서 start bit 감지 후 반 비트만큼 기다리는 이유는?
<details><summary>답</summary>

비트 경계 근처는 값이 바뀌는 중이라 불안정하므로, 반 비트를 기다려 start bit의 가운데로 이동한 뒤 1bit씩 기다리면 매 비트의 가운데에서 샘플링하게 된다. 가운데는 송·수신 클럭 오차와 지연에 가장 여유(마진)가 크다. 16배 오버샘플링에서는 8 tick 후 16 tick마다 샘플링.
</details>

**Q17.** UART TX 출력을 레지스터 출력으로 내보내는 이유와 reset 시 tx 값은?
<details><summary>답</summary>

조합 출력은 상태가 바뀌는 순간 글리치가 생길 수 있고, 수신 측이 1→0 하강을 start bit로 인식하므로 가짜 start bit가 될 수 있다. reset 시 tx = 1 (idle High).
</details>

**Q18.** Parity bit의 원리와 한계는?
<details><summary>답</summary>

데이터의 1의 개수를 짝수(even) 또는 홀수(odd)로 맞추는 1bit를 추가해 오류를 검출. 1bit(홀수 개) 오류는 검출하지만 2, 4… 짝수 개 비트가 깨지면 검출 못 하고, 정정은 불가.
</details>

**Q19.** `$display`와 `$strobe`의 차이는?
<details><summary>답</summary>

`$display`는 Active 영역에서 즉시 출력되어 non-blocking 갱신 전 값이 나올 수 있고, `$strobe`는 타임스텝 끝(모든 NBA 갱신 후)에 출력되어 최종값을 보여준다.
</details>

**Q20.** Setup time, hold time 위반의 결과와 각각의 해결법은?
<details><summary>답</summary>

메타스테이빌리티. Setup 위반: 클럭 주파수 낮추기, 파이프라이닝, 조합 논리 줄이기. Hold 위반: 지연 버퍼 삽입 (클럭을 낮춰도 해결 안 됨).
</details>

---

## B. 계산 문제

**Q21.** 100MHz 클럭으로 1kHz tick을 만들 때 F_COUNT와 카운터 비트 수는?
<details><summary>답</summary>

F_COUNT = 100,000,000 / 1,000 = **100,000**, 비교값 99,999, 비트 수 = `$clog2(100,000)` = **17bit** (2¹⁷ = 131,072)
</details>

**Q22.** 100MHz에서 duty 50% 800Hz 클럭(토글 방식)을 만들려면 몇 클럭마다 토글하나?
<details><summary>답</summary>

주기 = 100M / 800 = 125,000클럭 → 반주기 **62,500클럭**마다 토글 (비교값 62,499), 16bit 카운터.
</details>

**Q23.** 0~9999 카운터, 0~59 카운터, 0~23 카운터의 비트 폭은?
<details><summary>답</summary>

14bit (2¹⁴=16384), 6bit (64), 5bit (32)
</details>

**Q24.** UART 9600bps, 100MHz 기준 (a) 1bit당 클럭 수 (b) 16배 오버샘플 tick의 F_COUNT (c) 1 프레임 시간 (d) 초당 최대 전송 바이트 수
<details><summary>답</summary>

(a) 100M / 9600 = 10,416 (b) 100M / 153,600 = 651 (c) 10bit × 104.17µs ≈ 1.04ms (d) 9600 / 10 = 960 byte/s
</details>

**Q25.** 115200bps, 16배 오버샘플링, 100MHz일 때 F_COUNT와 실제 baud 오차는?
<details><summary>답</summary>

100M / (115200×16) = 54.25 → **54**. 실제 = 100M / (54×16) = 115,740.7bps → 오차 약 **+0.47%** (±2~3% 이내라 통신 가능)
</details>

**Q26.** 문자 `'A'`(8'h41)를 9600-8-N-1로 보낼 때 선 위 비트열을 idle부터 쓰라. Even parity를 쓴다면 parity bit는?
<details><summary>답</summary>

`0x41 = 0100_0001` → LSB first: 1 0 0 0 0 0 1 0
선: `1(idle) 0(start) 1 0 0 0 0 0 1 0 1(stop) 1(idle)`
1의 개수 2개(짝수) → even parity = **0** (odd parity면 1)
</details>

**Q27.** tclk-q = 1ns, 조합 최대 지연 = 6ns, tsu = 1ns일 때 최대 동작 주파수는? 조합 경로 중간에 레지스터를 넣어 3ns + 3ns로 나누면?
<details><summary>답</summary>

Tmin = 1 + 6 + 1 = 8ns → fmax = **125MHz**. 파이프라인: 1 + 3 + 1 = 5ns → **200MHz** (대신 latency 1클럭 증가)
</details>

**Q28.** 8bit 시프트+AND 디바운서가 1MHz tick으로 샘플링할 때 안정 판단 시간은? 100MHz 그대로 샘플링하면?
<details><summary>답</summary>

8 × 1µs = **8µs** / 8 × 10ns = **80ns** (채터링 수 ms를 걸러내기엔 짧음)
</details>

---

## C. 코드 분석

**Q29.** 클럭 엣지 직전 a=1, b=2, c=3일 때 엣지 후 a, b, c 값은?
```verilog
// (1)
always @(posedge clk) begin a = b; b = c; c = a; end
// (2)
always @(posedge clk) begin a <= b; b <= c; c <= a; end
```
<details><summary>답</summary>

(1) a=2, b=3, c=2 (c는 이미 바뀐 a=2)
(2) a=2, b=3, c=1 (모두 엣지 직전 값으로 계산)
</details>

**Q30.** 아래 코드는 몇 개의 FF로 합성되며 어떻게 동작하는가? 올바르게 고쳐라.
```verilog
always @(posedge clk) begin
    q1 = d;
    q2 = q1;
    q3 = q2;
end
```
<details><summary>답</summary>

blocking이라 q1, q2, q3가 한 클럭에 모두 d가 됨 → 사실상 FF 1개(q3 = d를 1클럭 지연). 3단 시프트 레지스터를 원하면 `q1 <= d; q2 <= q1; q3 <= q2;`
</details>

**Q31.** 다음 코드의 문제점과 수정 방법은?
```verilog
always @(*) begin
    case (sel)
        2'b00: y = a;
        2'b01: y = b;
        2'b10: y = c;
    endcase
end
```
<details><summary>답</summary>

sel = 2'b11일 때 y가 할당되지 않음 → latch 생성. `default: y = 0;` 추가 또는 case 위에 `y = 0;` 기본값.
</details>

**Q32.** 다음 코드의 문제는?
```verilog
always @(*) begin
    if (c_state == RUN) counter = counter + 1;
end
```
<details><summary>답</summary>

조합 블록에서 자기 자신을 갱신 → **조합 루프**(시뮬 무한 루프, 합성 경고, 타이밍 분석 불가) + else 없음 → latch. 카운터는 `always @(posedge clk)` 순차 블록에서 `<=`로.
</details>

**Q33.** 아래 두 always가 같은 클럭에서 동작할 때 문제점은?
```verilog
always @(posedge clk) a = d;
always @(posedge clk) b = a;
```
<details><summary>답</summary>

Race condition: 어느 블록이 먼저 실행되느냐에 따라 b가 새 a(=d) 또는 이전 a가 됨. `<=`로 바꾸면 b는 항상 이전 a.
</details>

**Q34.** 다음 tick_gen의 버그를 찾아라.
```verilog
always @(posedge clk) begin
    if (run) begin
        if (cnt == F_COUNT-1) begin cnt <= 0; tick <= 1; end
        else begin cnt <= cnt + 1; tick <= 0; end
    end
end
```
<details><summary>답</summary>

① run = 0이 되는 순간 tick이 1이었다면 계속 1로 유지 → 윗단 카운터가 매 클럭 증가. run=0일 때 `tick <= 0` 추가. ② reset이 없어 초기값 x.
</details>

**Q35.** 다음 코드에서 합성 시 어떤 위험이 있는가?
```verilog
always @(posedge clk, posedge reset)
    if (reset | clear) cnt <= 0;
    else cnt <= cnt + 1;
```
<details><summary>답</summary>

비동기 리셋 조건에 clear가 OR로 섞여 리셋 핀 앞에 OR 게이트가 생길 수 있고, clear(조합 신호)의 글리치가 비동기 리셋으로 들어가 의도치 않게 리셋될 위험. `if (reset) cnt <= 0; else if (clear) cnt <= 0; else ...`로 분리.
</details>

**Q36.** SIPO 코드에서 `q <= {q[2:0], din};`과 `q <= {din, q[3:1]};`의 차이와 UART RX에 맞는 것은?
<details><summary>답</summary>

전자는 왼쪽 시프트(새 비트가 LSB로 들어와 처음 비트가 MSB로 감) → MSB-first(SPI). 후자는 오른쪽 시프트(새 비트가 MSB로) → 8번 후 처음 받은 비트가 [0]에 위치 → **LSB-first인 UART RX**에 맞음.
</details>

**Q37.** 아래 synchronizer 코드의 잘못된 점은?
```verilog
always @(posedge clk) begin
    s1 <= async_in;
    s2 <= s1 & enable;
end
assign out = s1;
```
<details><summary>답</summary>

① 두 FF 사이에 조합 논리(`& enable`) → 해소 시간 감소 ② 첫 번째 FF(s1)를 출력으로 사용 → 메타스테이블 값 전달 ③ reset 없음. → `s2 <= s1;`, `assign out = s2;`
</details>

---

## D. FSM / 패턴 검출기

**Q38.** "0101" 검출 Mealy FSM (non-overlap)의 상태 전이표를 작성하라.
<details><summary>답</summary>

| 현재 | din=0 | din=1 (출력) |
|---|---|---|
| S0 | S1 | S0 |
| S1(`0`) | S1 | S2 |
| S2(`01`) | S3 | S0 |
| S3(`010`) | S1 | S0 (출력 1) |
</details>

**Q39.** 위를 overlap으로 바꾸면 무엇이 달라지는가? Moore로 바꾸면 상태 수는?
<details><summary>답</summary>

S3에서 din=1(검출)일 때 S0 대신 **S2**로 간다(`0101`의 끝 `01` 재사용). Moore는 검출 상태 S4가 추가되어 **5개**. Moore overlap은 S4에서 din=0 → S3, din=1 → S0.
</details>

**Q40.** 입력 `0 1 0 1 0 1 0 1` (왼쪽부터)에 대해 "0101" 검출기의 검출 횟수를 overlap / non-overlap으로 각각 쓰라.
<details><summary>답</summary>

Overlap: 4, 6, 8번째 비트에서 → **3회** / Non-overlap: 4, 8번째 → **2회**
</details>

**Q41.** "101" Moore overlap 검출기에 `1 0 1 0 1 1 0 1`이 들어올 때 상태 변화와 검출 횟수는? (S0:없음, S1:`1`, S2:`10`, S3:`101`)
<details><summary>답</summary>

S0 →1 S1 →0 S2 →1 **S3** →0 S2 →1 **S3** →1 S1 →0 S2 →1 **S3** → **3회** (Moore라 각각 S3에 들어간 다음 클럭 동안 출력 1)
</details>

**Q42.** Mealy와 Moore에서 "0101"의 마지막 1이 들어온 시점 대비 출력 시점 차이는?
<details><summary>답</summary>

Mealy는 S3에서 din=1이 들어온 **그 클럭**(조합 출력)에 바로 1. Moore는 다음 엣지에서 S4로 바뀐 뒤 1 → **1클럭 늦음**.
</details>

**Q43.** 버튼 하나로 RUN ↔ STOP을 토글하는 FSM을 설계할 때 버튼을 레벨로 쓰면 안 되는 이유와 해결은?
<details><summary>답</summary>

버튼을 누르고 있는 동안 계속 1이라 매 클럭 RUN↔STOP이 반복 토글된다. debounce 후 **엣지 검출로 1클럭 펄스**를 만들어 FSM 입력으로 사용.
</details>

**Q44.** UART RX FSM의 4개 상태와 각 상태의 tick 카운트 조건을 쓰라 (16배 오버샘플링).
<details><summary>답</summary>

IDLE: rx==0이면 START / START: tick 8개(cnt==7) → DATA / DATA: tick 16개마다 1bit 샘플·시프트, 8bit 후 STOP / STOP: tick 16개 후 rx_done=1, IDLE
</details>

---

## E. 서술형 (설계 가이드)

**Q45.** 순차 로직을 설계할 때 지켜야 할 규칙을 5가지 이상 쓰라.
<details><summary>답</summary>

① `always @(posedge clk, posedge rst)` + non-blocking ② 모든 FF에 reset(초기값) ③ 하나의 클럭으로 동기 설계, 느린 동작은 tick(enable) ④ 한 always에서 `=`/`<=` 혼용 금지 ⑤ 같은 reg를 여러 always에서 할당 금지 ⑥ 외부 비동기 입력은 synchronizer ⑦ 조합 로직으로 클럭/리셋 생성 금지 ⑧ 조합(next 계산)과 순차(저장)를 분리 (`_reg/_next`)
</details>

**Q46.** "분주 클럭으로 카운터를 돌려도 되나요?"라는 질문에 답하라.
<details><summary>답</summary>

FPGA에서는 권장하지 않는다. 로직으로 만든 클럭은 전용 글로벌 클럭망을 못 타서 skew가 크고, 원 클럭과 분주 클럭 사이에 CDC 비슷한 문제와 STA 복잡도가 생긴다. 원 클럭을 그대로 쓰고 N클럭마다 1클럭 tick을 만들어 enable로 쓰는 것이 정석이며, 진짜 다른 주파수가 필요하면 PLL/MMCM을 쓴다. ASIC에서 분주 클럭을 쓰면 `create_generated_clock`으로 정의해야 한다.
</details>

**Q47.** 플립플롭의 장점과 단점을 쓰라.
<details><summary>답</summary>

장점: 글리치 제거, 동기화로 타이밍 예측·STA 용이, 상태 저장(FSM, 카운터), 파이프라이닝으로 동작 주파수 향상
단점: 클럭 사이클만큼 latency, 면적·비용 증가, 클럭 토글로 전력·발열 증가, skew/jitter 관리 필요
</details>

**Q48.** 직렬 통신과 병렬 통신을 비교하라.
<details><summary>답</summary>

직렬: 1 line, 선이 적어 비용↓, 장거리 유리, 속도 느림, TX/RX 로직 복잡 (UART, SPI, I²C, USB). 병렬: 여러 line, 빠름, 로직 단순, 선 간 skew와 crosstalk로 단거리용 (메모리 버스).
</details>

**Q49.** UART + FIFO 구조에서 FIFO가 필요한 이유는?
<details><summary>답</summary>

단순 loopback은 TX가 송신 중(busy)일 때 다음 바이트가 수신되면 처리하지 못하고 놓친다. FIFO가 수신·송신 속도 차이와 몰려 들어오는 데이터(burst)를 임시 저장해 흡수한다. (동기 FIFO는 같은 클럭 → CDC 해결용이 아닌 버퍼)
</details>

**Q50.** 외부 입력(버튼, SR04 echo, UART rx)을 받을 때 고려할 사항은?
<details><summary>답</summary>

클럭과 비동기이므로 CDC 환경 → 2-FF synchronizer로 메타스테이블 확률 감소. 기계식 버튼은 채터링 → debouncer. 레벨이 아닌 이벤트로 쓰려면 엣지 검출로 1클럭 펄스. 외부 응답을 기다리는 FSM 상태에는 timeout.
</details>

---

## F. 코드 작성

**Q51.** 4x1 MUX를 case문으로 작성하라 (latch 없이).
<details><summary>답</summary>

```verilog
module mux_4x1 (
    input  [1:0] sel,
    input  [3:0] in0, in1, in2, in3,
    output reg [3:0] y
);
    always @(*) begin
        case (sel)
            2'b00: y = in0;
            2'b01: y = in1;
            2'b10: y = in2;
            2'b11: y = in3;
            default: y = 4'b0000;
        endcase
    end
endmodule
```
</details>

**Q52.** Active-low 2x4 디코더를 작성하라.
<details><summary>답</summary>

```verilog
module decoder_2x4 (
    input  [1:0] sel,
    output reg [3:0] y
);
    always @(*) begin
        case (sel)
            2'b00: y = 4'b1110;
            2'b01: y = 4'b1101;
            2'b10: y = 4'b1011;
            2'b11: y = 4'b0111;
            default: y = 4'b1111;
        endcase
    end
endmodule
```
</details>

**Q53.** 파라미터화된 tick_gen(100MHz → 100Hz)을 작성하라.
<details><summary>답</summary>

```verilog
module tick_gen #(parameter F_COUNT = 100_000_000 / 100) (
    input  clk, rst,
    output reg o_tick
);
    reg [$clog2(F_COUNT)-1:0] cnt;
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            cnt <= 0; o_tick <= 1'b0;
        end else if (cnt == F_COUNT - 1) begin
            cnt <= 0; o_tick <= 1'b1;
        end else begin
            cnt <= cnt + 1; o_tick <= 1'b0;
        end
    end
endmodule
```
</details>

**Q54.** 2-FF synchronizer + 상승 엣지 검출기를 작성하라.
<details><summary>답</summary>

```verilog
module sync_edge (
    input  clk, rst, async_in,
    output o_pulse
);
    reg s1, s2, s3;
    always @(posedge clk, posedge rst) begin
        if (rst) {s3, s2, s1} <= 3'b000;
        else     {s3, s2, s1} <= {s2, s1, async_in};
    end
    assign o_pulse = s2 & ~s3;   // 동기화된 s2의 상승 엣지
endmodule
```
</details>

**Q55.** 8bit PISO (load, shift, LSB first)를 작성하라.
<details><summary>답</summary>

```verilog
module piso8 (
    input        clk, rst, load, shift,
    input  [7:0] din,
    output       sout
);
    reg [7:0] sr;
    always @(posedge clk, posedge rst) begin
        if (rst)        sr <= 8'h00;
        else if (load)  sr <= din;
        else if (shift) sr <= {1'b0, sr[7:1]};
    end
    assign sout = sr[0];
endmodule
```
</details>

**Q56.** "101" 검출 Moore FSM (overlap)을 3-always 스타일로 작성하라.
<details><summary>답</summary>

```verilog
module seq101 (input clk, rst, din, output detect);
    localparam S0=2'd0, S1=2'd1, S2=2'd2, S3=2'd3;
    reg [1:0] c_state, n_state;

    always @(posedge clk, posedge rst)
        if (rst) c_state <= S0;
        else     c_state <= n_state;

    always @(*) begin
        n_state = c_state;
        case (c_state)
            S0: n_state = din ? S1 : S0;
            S1: n_state = din ? S1 : S2;
            S2: n_state = din ? S3 : S0;
            S3: n_state = din ? S1 : S2;
            default: n_state = S0;
        endcase
    end

    assign detect = (c_state == S3);
endmodule
```
</details>

**Q57.** Reset synchronizer(비동기 assert, 동기 deassert)를 작성하라.
<details><summary>답</summary>

```verilog
module rst_sync (input clk, rst_n_in, output rst_n);
    reg r1, r2;
    always @(posedge clk or negedge rst_n_in)
        if (!rst_n_in) {r2, r1} <= 2'b00;
        else           {r2, r1} <= {r1, 1'b1};
    assign rst_n = r2;
endmodule
```
</details>

---

# Part 4. 시험 직전 한 장 요약

| 키워드 | 한 줄 |
|---|---|
| 조합 | 현재 입력만, `assign`/`@(*)` + `=`, 할당 누락 → latch |
| 순차 | 입력 + 상태, `@(posedge clk)` + `<=`, reset 필수 |
| MUX | sel로 하나 선택, if=우선순위 체인 / case=병렬 |
| Decoder | n → 2ⁿ 중 하나, FND com은 active-low `1110` |
| Counter | 비트 = `$clog2(MAX+1)`, 경계 wrap-around, 동기식 사용 |
| tick_gen | N-1에서 1클럭 펄스, 모든 경로에서 0으로, 분주 클럭 대신 enable |
| Latch | 레벨 트리거, 의도치 않은 latch 금지 → default / else / 기본값 |
| F/F | 엣지 트리거, setup/hold 위반 → 메타스테이블 |
| Synchronizer | 2-FF, 1bit 전용, 2번째 출력 사용, 사이에 로직 금지 |
| SIPO / PISO | RX·debounce / TX, UART는 LSB first → 오른쪽 시프트 |
| Blocking | `=` 즉시, 순서 영향, 조합 |
| Non-blocking | `<=` 타임스텝 끝 동시 갱신, 순서 무관, 순차 |
| Race | 같은 시간 실행 순서 미정 → `<=`, 단일 드라이버, TB는 negedge |
| Reset | 동기(ASIC, 글리치 강함) / 비동기(FPGA, 즉시) / 비동기 assert·동기 deassert / active-low 이유 |
| CDC | 1bit=2FF, 펄스=toggle, 멀티비트=Gray 비동기 FIFO / handshake |
| FSM | next(CL) + state reg(SL) + output(CL), 비동기 리셋, full case, localparam |
| Moore/Mealy | 상태만 vs 상태+입력, 1클럭 늦음 vs 즉시, 상태 많음 vs 적음 |
| 패턴 검출 | 상태 = 맞은 접두사, overlap은 접미사 재사용 |
| UART | 비동기, idle 1, start 0, 8bit LSB first, stop 1, 10bit/frame, 9600 → 10416클럭, ×16 → 651, 가운데 샘플링(8 tick) |
| 코딩 가이드 | 순차 `<=` / 조합 `=` / 섞이면 `<=` / 혼용 금지 / multiple driven 금지 |
