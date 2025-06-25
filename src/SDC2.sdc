# SDC file for DE10-Standard UART LED project

# -----------------------------------------------------------------------------
# 1. Primary Clocks (주요 클럭)
# -----------------------------------------------------------------------------
# Create a primary clock for the 50MHz oscillator on the DE10-Standard board.
# -name: The name given to the clock. This name can be used in other constraints.
# -period: The clock period in nanoseconds (ns). 50MHz = 20ns.
# [get_ports {CLOCK_50}]: Specifies the physical port associated with this clock.
create_clock -name {sys_clk} -period "20.000" [get_ports {CLOCK_50}]

# -----------------------------------------------------------------------------
# 2. Input Delay (입력 지연)
# -----------------------------------------------------------------------------
# Constrain the input delay for the UART RX pin (GPIO_0_RX_DATA).
# This tells the tool how much time after the clock edge the input data can be considered stable.
# For asynchronous inputs like UART RX, it's often tricky. For a simple design like this,
# a rough estimate or "don't care" might be used for initial setup, but for robust design,
# you'd need to characterize the external sender.
# For simplicity, we assume a small delay relative to the system clock.
# -max: Maximum input delay in nanoseconds.
# -min: Minimum input delay in nanoseconds.
# -clock: The clock relative to which the delay is specified (sys_clk).
# [get_ports {GPIO_0_RX_DATA}]: The input port name.
# Note: For fully asynchronous inputs like UART, it's often more about path requirements
# (setup/hold) and false paths, but setting a timing constraint is still generally recommended.
set_input_delay -max 5.0 -clock [get_clocks {sys_clk}] [get_ports {GPIO_0_RX_DATA}]
set_input_delay -min 1.0 -clock [get_clocks {sys_clk}] [get_ports {GPIO_0_RX_DATA}]

# -----------------------------------------------------------------------------
# 3. Output Delay (출력 지연)
# -----------------------------------------------------------------------------
# Constrain the output delay for the LEDs (LEDR).
# This tells the tool how much time after the clock edge the output data must be stable.
# LEDs typically don't have strict timing requirements, but it's good practice to constrain.
# -max: Maximum output delay.
# -min: Minimum output delay.
# -clock: The clock relative to which the delay is specified (sys_clk).
# [get_ports {LEDR[*]}] or [get_ports {LEDR[9]} ... [get_ports {LEDR[0]}]: The output port name.
set_output_delay -max 3.0 -clock [get_clocks {sys_clk}] [get_ports {LEDR[*]}]
set_output_delay -min 1.0 -clock [get_clocks {sys_clk}] [get_ports {LEDR[*]}]


# -----------------------------------------------------------------------------
# 4. Asynchronous Inputs and False Paths (비동기 입력 및 False Path)
# -----------------------------------------------------------------------------
# The KEY0 input is often used as an asynchronous reset.
# Timing analysis on asynchronous resets is generally not required unless they are
# synchronized internally.
# set_false_path: Tells the timing analyzer to ignore paths originating from this port.
# If KEY0 is synchronized (e.g., using a flip-flop synchronizer chain) within your design,
# you should NOT set it as a false path. For this simple case, it's a direct asynchronous reset.
set_false_path -from [get_ports {KEY0}]


# Existing lines...

# Output Delay for UART TX
set_output_delay -max 3.0 -clock [get_clocks {sys_clk}] [get_ports {GPIO_0_TX_DATA}]
set_output_delay -min 1.0 -clock [get_clocks {sys_clk}] [get_ports {GPIO_0_TX_DATA}]

# UART_RX_DATA is also asynchronous to the FPGA's internal clock.
# While we set input delay, for robust asynchronous data handling (like UART),
# you often need to consider asynchronous FIFOs or double/triple flip-flop synchronizers.
# If you are explicitly synchronizing the UART_RX_DATA inside uart_rx.v, then a false path
# might not be appropriate for the synchronized path. However, for the raw input, it can be useful.
# For this basic example, if `uart_rx` module handles the asynchronous nature, we might set the false path
# for direct paths, but still analyze the paths to the synchronization flops.
# It's a complex topic for advanced designs. For this simple example, we'll keep the input delay.
# If you decide to handle it purely asynchronously and not analyze paths from this pin to the clock,
# you might use:
# set_false_path -from [get_ports {GPIO_0_RX_DATA}]
# However, the `uart_rx` module implicitly synchronizes the data by sampling it with the clock.
# So, for the sampling path inside `uart_rx`, input delay constraints are more appropriate.