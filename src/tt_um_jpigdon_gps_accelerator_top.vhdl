library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tt_um_jpigdon_gps_accelerator_top is
    port (
        ui_in   : in  std_logic_vector(7 downto 0);
        uo_out  : out std_logic_vector(7 downto 0);
        uio_in  : in  std_logic_vector(7 downto 0);
        uio_out : out std_logic_vector(7 downto 0);
        uio_oe  : out std_logic_vector(7 downto 0);
        ena     : in  std_logic;
        clk     : in  std_logic;
        rst_n   : in  std_logic
    );
end tt_um_jpigdon_gps_accelerator_top;

architecture Behavioral of tt_um_jpigdon_gps_accelerator_top is
    constant OUTPUT_DATA_WIDTH : integer := 16;
    constant INPUT_DATA_WIDTH : integer := 16;
    constant ADDR_WIDTH : integer := 5;
    --constant ADDR_WIDTH : integer := 6;
    constant OVERSAMPLE_RATIO : integer := 4;
    constant TRACK_LEN_WIDTH : integer := 2;
    constant ACCU_WIDTH : integer := 14;
    constant ACCU_OUTPUT_WIDTH : integer := 12;
    constant MASTER_COUNT_WIDTH_INT : integer := 10;
    constant MASTER_COUNT_WIDTH_FRAC : integer := 2;
    constant GPS_GOLD_TAPS_WIDTH : integer := 10;
    constant PHASE_ACCU_WIDTH : integer := 16;
    constant PHASE_COUNT_WIDTH : integer := 8;
    constant PHASE_INC_WIDTH : integer := 8;
    constant NUM_TRACK_CHANNELS : integer := 3;
    --constant NUM_TRACK_CHANNELS : integer := 4;

    component control_system is
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
        track_len_slv : out std_logic_vector((NUM_TRACK_CHANNELS*TRACK_LEN_WIDTH)-1 downto 0);
        track_channel_update : out std_logic_vector(NUM_TRACK_CHANNELS-1 downto 0);

        track_i_accu_val : in std_logic_vector((NUM_TRACK_CHANNELS *3* ACCU_OUTPUT_WIDTH)-1 downto 0);
        track_q_accu_val : in std_logic_vector((NUM_TRACK_CHANNELS *3* ACCU_OUTPUT_WIDTH)-1 downto 0);
        track_phase_inc: out std_logic_vector((NUM_TRACK_CHANNELS * PHASE_INC_WIDTH)-1 downto 0);
        track_time : out std_logic_vector(NUM_TRACK_CHANNELS*(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC)-1 downto 0);
        track_sv: out std_logic_vector((NUM_TRACK_CHANNELS*GPS_GOLD_TAPS_WIDTH)-1 downto 0);


        reset   : in  std_logic;        
        clk     : in  std_logic
    );
    end component;

    component acq_and_track_subsystem is
    generic(
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
        i_chan : in std_logic;
        q_chan : in std_logic;

        acq_begin : in std_logic;

        phase_inc_start : in std_logic_vector(PHASE_INC_WIDTH-1 downto 0);
        phase_inc_step : in std_logic_vector(PHASE_INC_WIDTH-1 downto 0);
        phase_inc_count : in std_logic_vector(PHASE_COUNT_WIDTH-1 downto 0);
        sv_test_taps: in std_logic_vector(GPS_GOLD_TAPS_WIDTH-1 downto 0);

        acq_busy : out std_logic;
        curr_time_offset_test : out std_logic_vector(GPS_GOLD_TAPS_WIDTH-1 downto 0);
        curr_ph_inc_test : out std_logic_vector(PHASE_INC_WIDTH-1 downto 0);

        master_time_pulse : out std_logic;

        i_accu_val : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);
        q_accu_val : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);

        track_channel_en : in std_logic_vector(NUM_TRACK_CHANNELS-1 downto 0);
        track_len_slv : in std_logic_vector((NUM_TRACK_CHANNELS*TRACK_LEN_WIDTH)-1 downto 0);
        track_channel_update : in std_logic_vector(NUM_TRACK_CHANNELS-1 downto 0);

        track_i_accu_val : out std_logic_vector((NUM_TRACK_CHANNELS *3* ACCU_OUTPUT_WIDTH)-1 downto 0);
        track_q_accu_val : out std_logic_vector((NUM_TRACK_CHANNELS *3* ACCU_OUTPUT_WIDTH)-1 downto 0);
        track_phase_inc: in std_logic_vector((NUM_TRACK_CHANNELS * PHASE_INC_WIDTH)-1 downto 0);
        track_time : in std_logic_vector(NUM_TRACK_CHANNELS*(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC)-1 downto 0);
        track_sv: in std_logic_vector((NUM_TRACK_CHANNELS*GPS_GOLD_TAPS_WIDTH)-1 downto 0);

        reset   : in  std_logic;        
        clk     : in  std_logic
    );
    end component;

    signal spi_dom_csn :  std_logic;
    signal spi_dom_miso :  std_logic;
    signal spi_dom_mosi :  std_logic;
    signal spi_dom_clk :  std_logic;

    signal time_interrupt :  std_logic;
    signal time_pulse :  std_logic;
        
    signal acq_begin :  std_logic;
    signal acq_phase_inc_start :  std_logic_vector(PHASE_INC_WIDTH-1 downto 0);
    signal acq_phase_inc_step :  std_logic_vector(PHASE_INC_WIDTH-1 downto 0);
    signal acq_phase_inc_count :  std_logic_vector(PHASE_COUNT_WIDTH-1 downto 0);
    signal acq_sv_test_taps:  std_logic_vector(GPS_GOLD_TAPS_WIDTH-1 downto 0);

    signal acq_busy :  std_logic;
    signal acq_curr_time_offset_test :  std_logic_vector(GPS_GOLD_TAPS_WIDTH-1 downto 0);
    signal acq_curr_ph_inc_test :  std_logic_vector(PHASE_INC_WIDTH-1 downto 0);

    signal acq_i_accu_val :  std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);
    signal acq_q_accu_val :  std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);

    signal track_channel_en : std_logic_vector(NUM_TRACK_CHANNELS-1 downto 0);
    signal track_len_slv : std_logic_vector((NUM_TRACK_CHANNELS*TRACK_LEN_WIDTH)-1 downto 0);

    signal track_channel_update : std_logic_vector(NUM_TRACK_CHANNELS-1 downto 0);

    signal track_i_accu_val : std_logic_vector((NUM_TRACK_CHANNELS *3* ACCU_OUTPUT_WIDTH)-1 downto 0);
    signal track_q_accu_val : std_logic_vector((NUM_TRACK_CHANNELS *3* ACCU_OUTPUT_WIDTH)-1 downto 0);
    signal track_phase_inc: std_logic_vector((NUM_TRACK_CHANNELS * PHASE_INC_WIDTH)-1 downto 0);
    signal track_time : std_logic_vector(NUM_TRACK_CHANNELS*(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC)-1 downto 0);
    signal track_sv: std_logic_vector((NUM_TRACK_CHANNELS*GPS_GOLD_TAPS_WIDTH)-1 downto 0);


    signal i_chan : std_logic;
    signal q_chan : std_logic;

    signal reset_pos_logic : std_logic;

    
begin
    reset_pos_logic <= not rst_n;

    i_chan <= ui_in(0); -- these are real pins, connect them here
    q_chan <= ui_in(2);

    --from the webpage bit 0 is cs, 1 is MOSI (input), 2 MISO (output), 3 clk
    uio_oe <= "0100" & "0100";
    uio_out <= "0000" & '0' & spi_dom_miso & "00";

    spi_dom_csn <= uio_in(0);
    spi_dom_mosi <= uio_in(1);
    spi_dom_clk <= uio_in(3);

    --just the outputs
    uo_out <= "000000" & time_pulse & time_interrupt;

    control : control_system
    generic map(
        OUTPUT_DATA_WIDTH => OUTPUT_DATA_WIDTH,
        INPUT_DATA_WIDTH => INPUT_DATA_WIDTH,
        ADDR_WIDTH => ADDR_WIDTH,
        OVERSAMPLE_RATIO => OVERSAMPLE_RATIO,
        TRACK_LEN_WIDTH => TRACK_LEN_WIDTH,
        ACCU_WIDTH => ACCU_WIDTH,
        ACCU_OUTPUT_WIDTH =>ACCU_OUTPUT_WIDTH,
        MASTER_COUNT_WIDTH_INT => MASTER_COUNT_WIDTH_INT,
        MASTER_COUNT_WIDTH_FRAC => MASTER_COUNT_WIDTH_FRAC,
        GPS_GOLD_TAPS_WIDTH => GPS_GOLD_TAPS_WIDTH,
        PHASE_ACCU_WIDTH => PHASE_ACCU_WIDTH,
        PHASE_COUNT_WIDTH => PHASE_COUNT_WIDTH,
        PHASE_INC_WIDTH => PHASE_INC_WIDTH,
        NUM_TRACK_CHANNELS => NUM_TRACK_CHANNELS
    )
    port map(

        spi_dom_csn => spi_dom_csn,
        spi_dom_miso => spi_dom_miso,
        spi_dom_mosi => spi_dom_mosi,
        spi_dom_clk => spi_dom_clk,

        time_interrupt => time_interrupt,
        time_pulse => time_pulse,
        
        acq_begin => acq_begin,
        acq_phase_inc_start => acq_phase_inc_start,
        acq_phase_inc_step => acq_phase_inc_step,
        acq_phase_inc_count => acq_phase_inc_count,
        acq_sv_test_taps => acq_sv_test_taps,

        acq_busy => acq_busy,
        acq_curr_time_offset_test => acq_curr_time_offset_test,
        acq_curr_ph_inc_test => acq_curr_ph_inc_test,

        acq_i_accu_val => acq_i_accu_val,
        acq_q_accu_val => acq_q_accu_val,

        track_channel_en => track_channel_en,
        track_len_slv => track_len_slv,
        track_channel_update => track_channel_update,
        track_i_accu_val => track_i_accu_val,
        track_q_accu_val => track_q_accu_val,
        track_phase_inc => track_phase_inc,
        track_time => track_time,
        track_sv => track_sv,

        reset => reset_pos_logic,
        clk => clk
    );

    acq_trk : acq_and_track_subsystem
        generic map(
            OVERSAMPLE_RATIO => OVERSAMPLE_RATIO,
            TRACK_LEN_WIDTH => TRACK_LEN_WIDTH,
            ACCU_WIDTH => ACCU_WIDTH,
            ACCU_OUTPUT_WIDTH => ACCU_OUTPUT_WIDTH,
            MASTER_COUNT_WIDTH_INT =>  MASTER_COUNT_WIDTH_INT,
            MASTER_COUNT_WIDTH_FRAC => MASTER_COUNT_WIDTH_FRAC,
            GPS_GOLD_TAPS_WIDTH => GPS_GOLD_TAPS_WIDTH,
            PHASE_ACCU_WIDTH => PHASE_ACCU_WIDTH,
            PHASE_COUNT_WIDTH => PHASE_COUNT_WIDTH,
            PHASE_INC_WIDTH => PHASE_INC_WIDTH,
            NUM_TRACK_CHANNELS => NUM_TRACK_CHANNELS
        )
        port map(
            i_chan => i_chan,
            q_chan => q_chan,

            acq_begin => acq_begin,

            phase_inc_start => acq_phase_inc_start,
            phase_inc_step => acq_phase_inc_step,
            phase_inc_count => acq_phase_inc_count,
            sv_test_taps => acq_sv_test_taps,

            acq_busy => acq_busy,
            curr_time_offset_test => acq_curr_time_offset_test,
            curr_ph_inc_test => acq_curr_ph_inc_test,

            master_time_pulse => time_pulse,

            i_accu_val => acq_i_accu_val,
            q_accu_val => acq_q_accu_val,

            track_channel_en => track_channel_en,
            track_len_slv => track_len_slv,
            track_channel_update => track_channel_update,
            track_i_accu_val => track_i_accu_val,
            track_q_accu_val => track_q_accu_val,
            track_phase_inc => track_phase_inc,
            track_time => track_time,
            track_sv => track_sv,

            reset   =>  reset_pos_logic,
            clk     => clk
        );
    


end Behavioral;