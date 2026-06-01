library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity control_system is
    generic(
        OUTPUT_DATA_WIDTH : integer := 16;
        INPUT_DATA_WIDTH : integer := 16;
        ADDR_WIDTH : integer := 6;
        OVERSAMPLE_RATIO : integer := 4;
        TRACK_LEN_WIDTH : integer := 2;
        ACCU_WIDTH : integer := 16;
        ACCU_OUTPUT_WIDTH : integer := 16;
        MASTER_COUNT_WIDTH_INT : integer := 10;
        MASTER_COUNT_WIDTH_FRAC : integer := 2;
        GPS_GOLD_TAPS_WIDTH : integer := 10;
        PHASE_ACCU_WIDTH : integer := 12;
        PHASE_COUNT_WIDTH : integer := 8;
        PHASE_INC_WIDTH : integer := 8;
        NUM_TRACK_CHANNELS : integer := 3
    );
    port (

        spi_dom_csn : in std_logic;
        spi_dom_miso : out std_logic;
        spi_dom_mosi : in std_logic;
        spi_dom_clk : in std_logic;

        time_interrupt : out std_logic;
        time_pulse : in std_logic;
        
        acq_begin : out std_logic;
        acq_phase_inc_start : out std_logic_vector(PHASE_INC_WIDTH-1 downto 0);
        acq_phase_inc_step : out std_logic_vector(PHASE_INC_WIDTH-1 downto 0);
        acq_phase_inc_count : out std_logic_vector(PHASE_COUNT_WIDTH-1 downto 0);
        acq_sv_test_taps: out std_logic_vector(GPS_GOLD_TAPS_WIDTH-1 downto 0);

        acq_busy : in std_logic;
        acq_curr_time_offset_test : in std_logic_vector(GPS_GOLD_TAPS_WIDTH-1 downto 0);
        acq_curr_ph_inc_test : in std_logic_vector(PHASE_INC_WIDTH-1 downto 0);

        acq_i_accu_val : in std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);
        acq_q_accu_val : in std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);

        track_channel_en : out std_logic_vector(NUM_TRACK_CHANNELS-1 downto 0);
        track_channel_update : out std_logic_vector(NUM_TRACK_CHANNELS-1 downto 0);
        track_len_slv : out std_logic_vector((NUM_TRACK_CHANNELS*TRACK_LEN_WIDTH)-1 downto 0); 


        track_i_accu_val : in std_logic_vector((NUM_TRACK_CHANNELS *3* ACCU_OUTPUT_WIDTH)-1 downto 0);
        track_q_accu_val : in std_logic_vector((NUM_TRACK_CHANNELS *3* ACCU_OUTPUT_WIDTH)-1 downto 0);
        track_phase_inc: out std_logic_vector((NUM_TRACK_CHANNELS * PHASE_INC_WIDTH)-1 downto 0);
        track_time : out std_logic_vector(NUM_TRACK_CHANNELS*(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC)-1 downto 0);
        track_sv: out std_logic_vector((NUM_TRACK_CHANNELS*GPS_GOLD_TAPS_WIDTH)-1 downto 0);


        reset   : in  std_logic;        
        clk     : in  std_logic
    );
end control_system;

architecture Behavioral of control_system is
    constant COMMAND_ADDR : integer := 0;
    constant ACQ_SV_ADDR : integer := 1;
    constant ACQ_PH_START_ADDR : integer := 2;
    constant ACQ_PH_INC_ADDR : integer := 3;
    constant ACQ_PH_COUNT_ADDR : integer := 4;
    constant ACQ_I_VAL_ADDR : integer := 5;
    constant ACQ_Q_VAL_ADDR : integer := 6;
    constant ACQ_CURR_PINC_ADDR : integer := 7;
    constant ACQ_CURR_TIME_ADDR : integer := 8;
    constant TRK_CONFIG_ADDR : integer := 9;
    constant TRK_BASE_ADDR : integer := 10;
    constant TRK_CH_INC : integer := 6;
    constant TRK_TIME_OFFSET : integer := 0;
    constant TRK_PHASE_OFFSET : integer := 1;
    constant TRK_SV_OFFSET : integer := 2;

    constant TRK_I_EARLY_OFFSET : integer := 0;
    constant TRK_Q_EARLY_OFFSET : integer := 1;
    constant TRK_I_MID_OFFSET : integer := 2;
    constant TRK_Q_MID_OFFSET : integer := 3;
    constant TRK_I_LATE_OFFSET : integer := 4;
    constant TRK_Q_LATE_OFFSET : integer := 5;



    constant COMMAND_ADDR_ACQ_BEGIN_POS : integer := 1;
    constant COMMAND_ADDR_INT_CLR_POS : integer := 0;

    constant TRACK_CONFIG_REG_UPDATE_BIT : integer := 0;
    constant TRACK_CONFIG_REG_EN_BIT : integer := 1;
    
    constant TRACK_CONFIG_REG_LEN_TOP : integer := 3;
    constant TRACK_CONFIG_REG_LEN_BOTTOM : integer := 2;
    constant TRACK_CONFIG_REG_CH_STRIDE : integer := 4;

    component spi_control_if is
    generic(
        OUTPUT_DATA_WIDTH : integer := 16;
        INPUT_DATA_WIDTH : integer := 16;
        ADDR_WIDTH : integer := 5
    );
    port (
        spi_dom_csn : in std_logic;
        spi_dom_miso : out std_logic;
        spi_dom_mosi : in std_logic;
        spi_dom_clk : in std_logic;
        read_op_req : out std_logic;
        read_update_strobe : in std_logic;
        write_op_strobe : out std_logic;
        op_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        write_op_data : out std_logic_vector(OUTPUT_DATA_WIDTH-1 downto 0);
        read_op_data : in std_logic_vector(OUTPUT_DATA_WIDTH-1 downto 0);
        reset   : in  std_logic;        
        clk     : in  std_logic
    );
    end component;

    signal spi_read_op_req :  std_logic;
    signal spi_read_update_strobe :  std_logic;
    signal spi_write_op_strobe : std_logic;
    signal spi_op_addr :  std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal spi_op_addr_reg :  std_logic_vector(ADDR_WIDTH-1 downto 0);

    signal spi_write_op_data : std_logic_vector(OUTPUT_DATA_WIDTH-1 downto 0);
    signal spi_read_op_data : std_logic_vector(OUTPUT_DATA_WIDTH-1 downto 0);

    signal acq_phase_inc_start_reg :  std_logic_vector(PHASE_INC_WIDTH-1 downto 0);
    signal acq_phase_inc_step_reg : std_logic_vector(PHASE_INC_WIDTH-1 downto 0);
    signal acq_phase_inc_count_reg : std_logic_vector(PHASE_COUNT_WIDTH-1 downto 0);
    signal acq_sv_test_taps_reg:  std_logic_vector(GPS_GOLD_TAPS_WIDTH-1 downto 0);

    signal trk_channel_config_reg : std_logic_vector((NUM_TRACK_CHANNELS*(TRACK_CONFIG_REG_CH_STRIDE-1))-1 downto 0);
    signal track_phase_inc_reg: std_logic_vector((NUM_TRACK_CHANNELS * PHASE_INC_WIDTH)-1 downto 0);
    signal track_time_reg : std_logic_vector(NUM_TRACK_CHANNELS*(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC)-1 downto 0);
    signal track_sv_reg: std_logic_vector((NUM_TRACK_CHANNELS*GPS_GOLD_TAPS_WIDTH)-1 downto 0);


    signal interrupt_flag_int : std_logic;
    
begin

    spi_if : spi_control_if
        generic map(
            OUTPUT_DATA_WIDTH => OUTPUT_DATA_WIDTH,
            INPUT_DATA_WIDTH => INPUT_DATA_WIDTH,
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            spi_dom_csn => spi_dom_csn,
            spi_dom_miso => spi_dom_miso,
            spi_dom_mosi => spi_dom_mosi,
            spi_dom_clk => spi_dom_clk,
        
            read_op_req => spi_read_op_req,
            read_update_strobe => spi_read_update_strobe,
            write_op_strobe => spi_write_op_strobe,
            op_addr => spi_op_addr,
            write_op_data => spi_write_op_data,
            read_op_data => spi_read_op_data,
            reset   => reset,
            clk     => clk
        );

    acq_phase_inc_start <= acq_phase_inc_start_reg;
    acq_phase_inc_step <= acq_phase_inc_step_reg;
    acq_phase_inc_count <= acq_phase_inc_count_reg;
    acq_sv_test_taps <= acq_sv_test_taps_reg;
    
    track_phase_inc <= track_phase_inc_reg;
    track_time <= track_time_reg;
    track_sv <= track_sv_reg;

    track_cfg : for i in 0 to NUM_TRACK_CHANNELS-1 generate
      track_channel_en(i) <= trk_channel_config_reg(((TRACK_CONFIG_REG_CH_STRIDE-1)*i));
      track_len_slv((TRACK_LEN_WIDTH*(i+1))-1 downto i*TRACK_LEN_WIDTH) <=  trk_channel_config_reg(((TRACK_CONFIG_REG_CH_STRIDE-1)*(i+1))-1 downto ((TRACK_CONFIG_REG_CH_STRIDE-1)*(i+1))-TRACK_LEN_WIDTH);
    end generate track_cfg;
    time_interrupt <= interrupt_flag_int;

    spi_read_op_data <= x"0000" when to_integer(signed(spi_op_addr_reg)) = COMMAND_ADDR else
                        "000000" & acq_sv_test_taps_reg when to_integer(signed(spi_op_addr_reg)) = ACQ_SV_ADDR else
                        x"00" & acq_phase_inc_start_reg when to_integer(signed(spi_op_addr_reg)) = ACQ_PH_START_ADDR else
                        x"00" & acq_phase_inc_step_reg when to_integer(signed(spi_op_addr_reg)) = ACQ_PH_INC_ADDR else
                        x"00" & acq_phase_inc_count_reg when to_integer(signed(spi_op_addr_reg)) = ACQ_PH_COUNT_ADDR else
                        "0000" & acq_i_accu_val when to_integer(signed(spi_op_addr_reg)) = ACQ_I_VAL_ADDR else
                        "0000" & acq_q_accu_val when to_integer(signed(spi_op_addr_reg)) = ACQ_Q_VAL_ADDR else
                        x"00" & acq_curr_ph_inc_test when to_integer(signed(spi_op_addr_reg)) = ACQ_CURR_PINC_ADDR else
                        "000000" & acq_curr_time_offset_test when to_integer(signed(spi_op_addr_reg)) = ACQ_CURR_TIME_ADDR else
                        "0000" & track_i_accu_val((0+1)*3*ACCU_OUTPUT_WIDTH-0*ACCU_OUTPUT_WIDTH-1 downto (0+1)*3*ACCU_OUTPUT_WIDTH-(0+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*0)+TRK_I_EARLY_OFFSET else
                        "0000" & track_q_accu_val((0+1)*3*ACCU_OUTPUT_WIDTH-0*ACCU_OUTPUT_WIDTH-1 downto (0+1)*3*ACCU_OUTPUT_WIDTH-(0+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*0)+TRK_Q_EARLY_OFFSET else
                        "0000" & track_i_accu_val((0+1)*3*ACCU_OUTPUT_WIDTH-1*ACCU_OUTPUT_WIDTH-1 downto (0+1)*3*ACCU_OUTPUT_WIDTH-(1+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*0)+TRK_I_MID_OFFSET else
                        "0000" & track_q_accu_val((0+1)*3*ACCU_OUTPUT_WIDTH-1*ACCU_OUTPUT_WIDTH-1 downto (0+1)*3*ACCU_OUTPUT_WIDTH-(1+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*0)+TRK_Q_MID_OFFSET else
                        "0000" & track_i_accu_val((0+1)*3*ACCU_OUTPUT_WIDTH-2*ACCU_OUTPUT_WIDTH-1 downto (0+1)*3*ACCU_OUTPUT_WIDTH-(2+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*0)+TRK_I_LATE_OFFSET else
                        "0000" & track_q_accu_val((0+1)*3*ACCU_OUTPUT_WIDTH-2*ACCU_OUTPUT_WIDTH-1 downto (0+1)*3*ACCU_OUTPUT_WIDTH-(2+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*0)+TRK_Q_LATE_OFFSET else
                        "0000" & track_i_accu_val((1+1)*3*ACCU_OUTPUT_WIDTH-0*ACCU_OUTPUT_WIDTH-1 downto (1+1)*3*ACCU_OUTPUT_WIDTH-(0+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*1)+TRK_I_EARLY_OFFSET else
                        "0000" & track_q_accu_val((1+1)*3*ACCU_OUTPUT_WIDTH-0*ACCU_OUTPUT_WIDTH-1 downto (1+1)*3*ACCU_OUTPUT_WIDTH-(0+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*1)+TRK_Q_EARLY_OFFSET else
                        "0000" & track_i_accu_val((1+1)*3*ACCU_OUTPUT_WIDTH-1*ACCU_OUTPUT_WIDTH-1 downto (1+1)*3*ACCU_OUTPUT_WIDTH-(1+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*1)+TRK_I_MID_OFFSET else
                        "0000" & track_q_accu_val((1+1)*3*ACCU_OUTPUT_WIDTH-1*ACCU_OUTPUT_WIDTH-1 downto (1+1)*3*ACCU_OUTPUT_WIDTH-(1+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*1)+TRK_Q_MID_OFFSET else
                        "0000" & track_i_accu_val((1+1)*3*ACCU_OUTPUT_WIDTH-2*ACCU_OUTPUT_WIDTH-1 downto (1+1)*3*ACCU_OUTPUT_WIDTH-(2+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*1)+TRK_I_LATE_OFFSET else
                        "0000" & track_q_accu_val((1+1)*3*ACCU_OUTPUT_WIDTH-2*ACCU_OUTPUT_WIDTH-1 downto (1+1)*3*ACCU_OUTPUT_WIDTH-(2+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*1)+TRK_Q_LATE_OFFSET else
                        "0000" & track_i_accu_val((2+1)*3*ACCU_OUTPUT_WIDTH-0*ACCU_OUTPUT_WIDTH-1 downto (2+1)*3*ACCU_OUTPUT_WIDTH-(0+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*2)+TRK_I_EARLY_OFFSET else
                        "0000" & track_q_accu_val((2+1)*3*ACCU_OUTPUT_WIDTH-0*ACCU_OUTPUT_WIDTH-1 downto (2+1)*3*ACCU_OUTPUT_WIDTH-(0+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*2)+TRK_Q_EARLY_OFFSET else
                        "0000" & track_i_accu_val((2+1)*3*ACCU_OUTPUT_WIDTH-1*ACCU_OUTPUT_WIDTH-1 downto (2+1)*3*ACCU_OUTPUT_WIDTH-(1+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*2)+TRK_I_MID_OFFSET else
                        "0000" & track_q_accu_val((2+1)*3*ACCU_OUTPUT_WIDTH-1*ACCU_OUTPUT_WIDTH-1 downto (2+1)*3*ACCU_OUTPUT_WIDTH-(1+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*2)+TRK_Q_MID_OFFSET else
                        "0000" & track_i_accu_val((2+1)*3*ACCU_OUTPUT_WIDTH-2*ACCU_OUTPUT_WIDTH-1 downto (2+1)*3*ACCU_OUTPUT_WIDTH-(2+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*2)+TRK_I_LATE_OFFSET else
                        "0000" & track_q_accu_val((2+1)*3*ACCU_OUTPUT_WIDTH-2*ACCU_OUTPUT_WIDTH-1 downto (2+1)*3*ACCU_OUTPUT_WIDTH-(2+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*2)+TRK_Q_LATE_OFFSET else

                        -- "0000" & track_i_accu_val((3+1)*3*ACCU_OUTPUT_WIDTH-0*ACCU_OUTPUT_WIDTH-1 downto (3+1)*3*ACCU_OUTPUT_WIDTH-(0+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*3)+TRK_I_EARLY_OFFSET else
                        -- "0000" & track_q_accu_val((3+1)*3*ACCU_OUTPUT_WIDTH-0*ACCU_OUTPUT_WIDTH-1 downto (3+1)*3*ACCU_OUTPUT_WIDTH-(0+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*3)+TRK_Q_EARLY_OFFSET else
                        -- "0000" & track_i_accu_val((3+1)*3*ACCU_OUTPUT_WIDTH-1*ACCU_OUTPUT_WIDTH-1 downto (3+1)*3*ACCU_OUTPUT_WIDTH-(1+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*3)+TRK_I_MID_OFFSET else
                        -- "0000" & track_q_accu_val((3+1)*3*ACCU_OUTPUT_WIDTH-1*ACCU_OUTPUT_WIDTH-1 downto (3+1)*3*ACCU_OUTPUT_WIDTH-(1+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*3)+TRK_Q_MID_OFFSET else
                        -- "0000" & track_i_accu_val((3+1)*3*ACCU_OUTPUT_WIDTH-2*ACCU_OUTPUT_WIDTH-1 downto (3+1)*3*ACCU_OUTPUT_WIDTH-(2+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*3)+TRK_I_LATE_OFFSET else
                        -- "0000" & track_q_accu_val((3+1)*3*ACCU_OUTPUT_WIDTH-2*ACCU_OUTPUT_WIDTH-1 downto (3+1)*3*ACCU_OUTPUT_WIDTH-(2+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*3)+TRK_Q_LATE_OFFSET else
                        
                        -- "0000" & track_i_accu_val((0+1)*3*ACCU_OUTPUT_WIDTH-0*ACCU_OUTPUT_WIDTH-1 downto (0+1)*3*ACCU_OUTPUT_WIDTH-(0+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*0)+TRK_I_EARLY_OFFSET else
                        -- "0000" & track_q_accu_val((0+1)*3*ACCU_OUTPUT_WIDTH-0*ACCU_OUTPUT_WIDTH-1 downto (0+1)*3*ACCU_OUTPUT_WIDTH-(0+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*0)+TRK_Q_EARLY_OFFSET else
                        -- "0000" & track_i_accu_val((0+1)*3*ACCU_OUTPUT_WIDTH-1*ACCU_OUTPUT_WIDTH-1 downto (0+1)*3*ACCU_OUTPUT_WIDTH-(1+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*0)+TRK_I_MID_OFFSET else
                        -- "0000" & track_q_accu_val((0+1)*3*ACCU_OUTPUT_WIDTH-1*ACCU_OUTPUT_WIDTH-1 downto (0+1)*3*ACCU_OUTPUT_WIDTH-(1+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*0)+TRK_Q_MID_OFFSET else
                        -- "0000" & track_i_accu_val((0+1)*3*ACCU_OUTPUT_WIDTH-2*ACCU_OUTPUT_WIDTH-1 downto (0+1)*3*ACCU_OUTPUT_WIDTH-(2+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*0)+TRK_I_LATE_OFFSET else
                        -- "0000" & track_q_accu_val((0+1)*3*ACCU_OUTPUT_WIDTH-2*ACCU_OUTPUT_WIDTH-1 downto (0+1)*3*ACCU_OUTPUT_WIDTH-(2+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*0)+TRK_Q_LATE_OFFSET else
                        -- "0000" & track_i_accu_val((1+1)*3*ACCU_OUTPUT_WIDTH-0*ACCU_OUTPUT_WIDTH-1 downto (1+1)*3*ACCU_OUTPUT_WIDTH-(0+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*1)+TRK_I_EARLY_OFFSET else
                        -- "0000" & track_q_accu_val((1+1)*3*ACCU_OUTPUT_WIDTH-0*ACCU_OUTPUT_WIDTH-1 downto (1+1)*3*ACCU_OUTPUT_WIDTH-(0+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*1)+TRK_Q_EARLY_OFFSET else
                        -- "0000" & track_i_accu_val((1+1)*3*ACCU_OUTPUT_WIDTH-1*ACCU_OUTPUT_WIDTH-1 downto (1+1)*3*ACCU_OUTPUT_WIDTH-(1+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*1)+TRK_I_MID_OFFSET else
                        -- "0000" & track_q_accu_val((1+1)*3*ACCU_OUTPUT_WIDTH-1*ACCU_OUTPUT_WIDTH-1 downto (1+1)*3*ACCU_OUTPUT_WIDTH-(1+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*1)+TRK_Q_MID_OFFSET else
                        -- "0000" & track_i_accu_val((1+1)*3*ACCU_OUTPUT_WIDTH-2*ACCU_OUTPUT_WIDTH-1 downto (1+1)*3*ACCU_OUTPUT_WIDTH-(2+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*1)+TRK_I_LATE_OFFSET else
                        -- "0000" & track_q_accu_val((1+1)*3*ACCU_OUTPUT_WIDTH-2*ACCU_OUTPUT_WIDTH-1 downto (1+1)*3*ACCU_OUTPUT_WIDTH-(2+1)*ACCU_OUTPUT_WIDTH) when to_integer(signed(spi_op_addr_reg)) = TRK_BASE_ADDR+(TRK_CH_INC*1)+TRK_Q_LATE_OFFSET else
                        
                        x"0000";

    process(clk, reset) is
    begin
        if(reset = '1') then
            acq_phase_inc_start_reg <= (others => '0');
            acq_phase_inc_step_reg <= (others => '0');
            acq_phase_inc_count_reg <= (others => '0');
            acq_sv_test_taps_reg <= (others => '0');
            spi_op_addr_reg <= (others => '0');
            trk_channel_config_reg <= (others => '0');
            track_phase_inc_reg <= (others => '0');
            track_time_reg <= (others => '0');
            track_sv_reg <= (others => '0');
            interrupt_flag_int <= '0';
            spi_read_update_strobe <= '0';
            acq_begin <= '0';
            track_channel_update <= (others => '0');
        elsif(rising_edge(clk)) then
            acq_begin <= '0';
            spi_read_update_strobe <= '0';
            track_channel_update <= (others => '0');
            if(time_pulse = '1') then
                interrupt_flag_int <= '1';
            end if;

            if(spi_write_op_strobe = '1') then
                --update correct register
                if(to_integer(signed(spi_op_addr)) = COMMAND_ADDR)then
                    if(spi_write_op_data(COMMAND_ADDR_ACQ_BEGIN_POS) = '1') then
                        acq_begin <= '1';
                    end if;
                    if(spi_write_op_data(COMMAND_ADDR_INT_CLR_POS) = '1') then
                        interrupt_flag_int <= '0';
                    end if;
                elsif(to_integer(signed(spi_op_addr)) = ACQ_SV_ADDR) then
                    acq_sv_test_taps_reg <= spi_write_op_data(GPS_GOLD_TAPS_WIDTH-1 downto 0);
                elsif(to_integer(signed(spi_op_addr)) = ACQ_PH_START_ADDR) then
                    acq_phase_inc_start_reg <= spi_write_op_data(PHASE_INC_WIDTH-1 downto 0);
                elsif(to_integer(signed(spi_op_addr)) = ACQ_PH_INC_ADDR) then
                    acq_phase_inc_step_reg <= spi_write_op_data(PHASE_INC_WIDTH-1 downto 0);
                elsif(to_integer(signed(spi_op_addr)) = ACQ_PH_COUNT_ADDR) then
                    acq_phase_inc_count_reg <= spi_write_op_data(PHASE_COUNT_WIDTH-1 downto 0);
                elsif(to_integer(signed(spi_op_addr)) = TRK_CONFIG_ADDR) then
                    for i in 0 to NUM_TRACK_CHANNELS-1 loop
                        --only update the channels that are flagged for updates. 
                        if spi_write_op_data((TRACK_CONFIG_REG_CH_STRIDE*i)+1) = '1' then
                            track_channel_update(i) <= '1';
                            trk_channel_config_reg(((TRACK_CONFIG_REG_CH_STRIDE-1)*(i+1))-1 downto ((TRACK_CONFIG_REG_CH_STRIDE-1)*(i))) <= spi_write_op_data((TRACK_CONFIG_REG_CH_STRIDE*(i+1)-1) downto (TRACK_CONFIG_REG_CH_STRIDE*(i))+1);
                        else
                            track_channel_update(i) <= '0';
                            trk_channel_config_reg(((TRACK_CONFIG_REG_CH_STRIDE-1)*(i+1))-1 downto ((TRACK_CONFIG_REG_CH_STRIDE-1)*(i))) <= trk_channel_config_reg(((TRACK_CONFIG_REG_CH_STRIDE-1)*(i+1))-1 downto ((TRACK_CONFIG_REG_CH_STRIDE-1)*(i)));
                        end if; 
                    end loop;
                elsif(to_integer(signed(spi_op_addr)) = TRK_BASE_ADDR+(TRK_CH_INC*0)+TRK_TIME_OFFSET) then
                    track_time_reg(((0+1)*(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC))-1 downto ((0)*(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC))) <= spi_write_op_data((MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC)-1 downto 0);
                elsif(to_integer(signed(spi_op_addr)) = TRK_BASE_ADDR+(TRK_CH_INC*1)+TRK_TIME_OFFSET) then
                    track_time_reg(((1+1)*(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC))-1 downto ((1)*(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC))) <= spi_write_op_data((MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC)-1 downto 0);
                elsif(to_integer(signed(spi_op_addr)) = TRK_BASE_ADDR+(TRK_CH_INC*2)+TRK_TIME_OFFSET) then
                    track_time_reg(((2+1)*(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC))-1 downto ((2)*(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC))) <= spi_write_op_data((MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC)-1 downto 0);
                -- elsif(to_integer(signed(spi_op_addr)) = TRK_BASE_ADDR+(TRK_CH_INC*3)+TRK_TIME_OFFSET) then
                --     track_time_reg(((3+1)*(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC))-1 downto ((3)*(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC))) <= spi_write_op_data((MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC)-1 downto 0);
                elsif(to_integer(signed(spi_op_addr)) = TRK_BASE_ADDR+(TRK_CH_INC*0)+TRK_PHASE_OFFSET) then
                    track_phase_inc_reg(((0+1)*(PHASE_INC_WIDTH))-1 downto ((0)*(PHASE_INC_WIDTH))) <= spi_write_op_data((PHASE_INC_WIDTH)-1 downto 0);
                elsif(to_integer(signed(spi_op_addr)) = TRK_BASE_ADDR+(TRK_CH_INC*1)+TRK_PHASE_OFFSET) then
                    track_phase_inc_reg(((1+1)*(PHASE_INC_WIDTH))-1 downto ((1)*(PHASE_INC_WIDTH))) <= spi_write_op_data((PHASE_INC_WIDTH)-1 downto 0);
                elsif(to_integer(signed(spi_op_addr)) = TRK_BASE_ADDR+(TRK_CH_INC*2)+TRK_PHASE_OFFSET) then
                    track_phase_inc_reg(((2+1)*(PHASE_INC_WIDTH))-1 downto ((2)*(PHASE_INC_WIDTH))) <= spi_write_op_data((PHASE_INC_WIDTH)-1 downto 0);
                -- elsif(to_integer(signed(spi_op_addr)) = TRK_BASE_ADDR+(TRK_CH_INC*3)+TRK_PHASE_OFFSET) then
                --     track_phase_inc_reg(((3+1)*(PHASE_INC_WIDTH))-1 downto ((3)*(PHASE_INC_WIDTH))) <= spi_write_op_data((PHASE_INC_WIDTH)-1 downto 0);
                elsif(to_integer(signed(spi_op_addr)) = TRK_BASE_ADDR+(TRK_CH_INC*0)+TRK_SV_OFFSET) then
                    track_sv_reg(((0+1)*(GPS_GOLD_TAPS_WIDTH))-1 downto ((0)*(GPS_GOLD_TAPS_WIDTH))) <= spi_write_op_data((GPS_GOLD_TAPS_WIDTH)-1 downto 0);
                elsif(to_integer(signed(spi_op_addr)) = TRK_BASE_ADDR+(TRK_CH_INC*1)+TRK_SV_OFFSET) then
                    track_sv_reg(((1+1)*(GPS_GOLD_TAPS_WIDTH))-1 downto ((1)*(GPS_GOLD_TAPS_WIDTH))) <= spi_write_op_data((GPS_GOLD_TAPS_WIDTH)-1 downto 0);
                elsif(to_integer(signed(spi_op_addr)) = TRK_BASE_ADDR+(TRK_CH_INC*2)+TRK_SV_OFFSET) then
                    track_sv_reg(((2+1)*(GPS_GOLD_TAPS_WIDTH))-1 downto ((2)*(GPS_GOLD_TAPS_WIDTH))) <= spi_write_op_data((GPS_GOLD_TAPS_WIDTH)-1 downto 0);
                -- elsif(to_integer(signed(spi_op_addr)) = TRK_BASE_ADDR+(TRK_CH_INC*3)+TRK_SV_OFFSET) then
                --     track_sv_reg(((3+1)*(GPS_GOLD_TAPS_WIDTH))-1 downto ((3)*(GPS_GOLD_TAPS_WIDTH))) <= spi_write_op_data((GPS_GOLD_TAPS_WIDTH)-1 downto 0);
                end if;
            elsif(spi_read_op_req = '1') then --address will select the data to be passed back, just needs to stay stable
                spi_op_addr_reg <= spi_op_addr;
                spi_read_update_strobe <= '1';
            end if;
        end if;
    end process;


end Behavioral;
