library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity acquisition_mgmt_sm is
    generic(
        OVERSAMPLE_RATIO : integer := 4;
        ACCU_WIDTH : integer := 16;
        ACCU_OUTPUT_WIDTH : integer := 8;
        MASTER_COUNT_WIDTH_INT : integer := 10;
        MASTER_COUNT_WIDTH_FRAC : integer := 2;
        GPS_GOLD_TAPS_WIDTH : integer := 10;
        PHASE_ACCU_WIDTH : integer := 12;
        PHASE_COUNT_WIDTH : integer := 8;
        PHASE_INC_WIDTH : integer := 8
    );
    port (
        i_chan : in std_logic;
        q_chan : in std_logic;

        acq_begin : in std_logic;
        timing_period_strobe : in std_logic;

        master_timing_slv : in std_logic_vector(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC-1 downto 0); --other 

        phase_inc_start : in std_logic_vector(PHASE_INC_WIDTH-1 downto 0);
        phase_inc_step : in std_logic_vector(PHASE_INC_WIDTH-1 downto 0);
        phase_inc_count : in std_logic_vector(PHASE_COUNT_WIDTH-1 downto 0);

        sv_test_taps: in std_logic_vector(GPS_GOLD_TAPS_WIDTH-1 downto 0);

        acq_busy : out std_logic;
        curr_time_offset_test : out std_logic_vector(GPS_GOLD_TAPS_WIDTH-1 downto 0);
        curr_ph_inc_test : out std_logic_vector(PHASE_INC_WIDTH-1 downto 0);

        i_accu_val : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);
        q_accu_val : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);

        reset   : in  std_logic;        
        clk     : in  std_logic
    );
end acquisition_mgmt_sm;

architecture Behavioral of acquisition_mgmt_sm is
    component acq_complex_correlator_channel is
    generic(
        ACCU_WIDTH : integer := 16;
        ACCU_OUTPUT_WIDTH : integer := 8;
        GPS_GOLD_TAPS_WIDTH : integer := 10;
        PHASE_ACCU_WIDTH : integer := 12;
        PHASE_INC_WIDTH : integer := 8
    );
    port (
        i_chan : in std_logic;
        q_chan : in std_logic;

        gold_a_taps_slv : in std_logic_vector(GPS_GOLD_TAPS_WIDTH-1 downto 0);
        gold_a_load : in std_logic;
        gold_a_sync : in std_logic;
        gold_a_ena : in std_logic;

        gold_b_taps_slv : in std_logic_vector(GPS_GOLD_TAPS_WIDTH-1 downto 0);
        gold_b_load : in std_logic;
        gold_b_sync : in std_logic;
        gold_b_ena : in std_logic;

        gold_sel : in std_logic;

        ph_inc_slv : in  std_logic_vector(PHASE_INC_WIDTH-1 downto 0);
        ph_inc_load : in std_logic;
        nco_reset : in std_logic;
        nco_ena : in std_logic;

        accu_sync : in std_logic;
        accu_ena     : in  std_logic; --general channel enable

        i_accu_val : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);
        q_accu_val : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);

        reset   : in  std_logic;
        
        clk     : in  std_logic
    );
    end component;

    type AcqSM_state_type is (WAITING, PREPARING, TRIGGERED_WAIT_SOF, ACQUIRING);
    signal acq_state : AcqSM_state_type;

    signal time_search_step : integer range 0 to (2**GPS_GOLD_TAPS_WIDTH)-1;
    signal freq_search_step : integer range 0 to (2**PHASE_COUNT_WIDTH)-1;
    signal freq_search_max : integer range 0 to (2**PHASE_COUNT_WIDTH)-1;

    signal gold_a_load : std_logic;
    signal gold_a_sync : std_logic;
    signal gold_a_ena : std_logic;

    signal gold_b_load : std_logic;
    signal gold_b_sync : std_logic;
    signal gold_b_ena : std_logic;

    signal gold_sel : std_logic;

    signal ph_inc_current :  std_logic_vector(PHASE_INC_WIDTH-1 downto 0);
    --signal ph_inc_reg :  std_logic_vector(PHASE_INC_WIDTH-1 downto 0);
    signal ph_inc_load :  std_logic;
    signal nco_ena :  std_logic;

    signal accu_sync :  std_logic;
    signal accu_ena  :  std_logic; --general channel enable

    signal timing_int_part : std_logic_vector(MASTER_COUNT_WIDTH_INT-1 downto 0);
    signal timing_frac_part : std_logic_vector(MASTER_COUNT_WIDTH_FRAC-1 downto 0);

begin

    acq_busy <= '0' when acq_state = WAITING else '1';
    curr_time_offset_test <= std_logic_vector(to_unsigned(time_search_step, GPS_GOLD_TAPS_WIDTH));
    curr_ph_inc_test <= std_logic_vector(to_unsigned(freq_search_step, PHASE_INC_WIDTH));
    timing_int_part <= master_timing_slv(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC-1 downto MASTER_COUNT_WIDTH_FRAC);
    timing_frac_part <= master_timing_slv(MASTER_COUNT_WIDTH_FRAC-1 downto 0);

    acq_inst : acq_complex_correlator_channel
        generic map(
            ACCU_WIDTH => ACCU_WIDTH,
            ACCU_OUTPUT_WIDTH => ACCU_OUTPUT_WIDTH,
            GPS_GOLD_TAPS_WIDTH => GPS_GOLD_TAPS_WIDTH,
            PHASE_ACCU_WIDTH => PHASE_ACCU_WIDTH,
            PHASE_INC_WIDTH => PHASE_INC_WIDTH
        )
        port map(
            i_chan => i_chan,
            q_chan => q_chan,
            gold_a_taps_slv => sv_test_taps,
            gold_a_load => gold_a_load,
            gold_a_sync => gold_a_sync,
            gold_a_ena => gold_a_ena,
            gold_b_taps_slv => sv_test_taps,
            gold_b_load => gold_b_load,
            gold_b_sync => gold_b_sync,
            gold_b_ena => gold_b_ena,
            gold_sel => gold_sel,
            ph_inc_slv => ph_inc_current,
            ph_inc_load => ph_inc_load,
            nco_reset => reset,
            nco_ena => nco_ena,
            accu_sync => accu_sync,
            accu_ena  => accu_ena,
            i_accu_val => i_accu_val,
            q_accu_val => q_accu_val,
            reset   => reset,
            clk     => clk
        );

    process(acq_state) is
    begin
        case acq_state is
            when PREPARING=>
                gold_a_load <= '1';
                gold_b_load <= '1';
            when others=>
                gold_a_load <= '0';
                gold_b_load <= '0';
        end case;
    end process;

    process(acq_state, timing_frac_part) is
    begin
        case acq_state is
            when ACQUIRING=>
                if(to_integer(unsigned(timing_frac_part)) = OVERSAMPLE_RATIO-1) then
                    gold_a_ena <= '1';
                    gold_b_ena <= '1';
                else
                    gold_a_ena <= '0';
                    gold_b_ena <= '0';
                end if;
            when others=>
                gold_a_ena <= '0';
                gold_b_ena <= '0';
        end case;
    end process;

    process(acq_state, timing_period_strobe, gold_sel, timing_int_part, timing_frac_part, time_search_step) is
    begin
        case acq_state is
            when TRIGGERED_WAIT_SOF =>
                gold_a_sync <= timing_period_strobe;
                gold_b_sync <= '0';
            when ACQUIRING=>
                if(to_integer(unsigned(timing_frac_part)) = OVERSAMPLE_RATIO-1) then
                    if(to_integer(unsigned(timing_int_part)) = time_search_step+1) then
                        if(gold_sel = '0') then
                            gold_a_sync <= '0';
                            gold_b_sync <= '1';
                        else
                            gold_a_sync <= '1';
                            gold_b_sync <= '0';
                        end if;
                        
                    else
                        gold_a_sync <= '0';
                        gold_b_sync <= '0';
                    end if;
                else
                    gold_a_sync <= '0';
                    gold_b_sync <= '0';
                end if;
            when others=>
                gold_a_sync <= '0';
                gold_b_sync <= '0';
        end case;
    end process;

    process(acq_state) is
    begin
        case acq_state is
            when ACQUIRING=>
                accu_ena <= '1';
            when others=>
                accu_ena <= '0';
        end case;
    end process;

    process(acq_state) is
    begin
        case acq_state is
            when ACQUIRING=>
                nco_ena <= '1';
            when others=>
                nco_ena <= '0';
        end case;
    end process;

    process(acq_state,timing_period_strobe) is
    begin
        case acq_state is
            when ACQUIRING | TRIGGERED_WAIT_SOF=>
                accu_sync <= timing_period_strobe;
            when others=>
                accu_sync <= '0';
        end case;
    end process;

    process(clk, reset) is
    begin
        if reset = '1' then
            acq_state <= WAITING;
            time_search_step <= 0;
            freq_search_step <= 0;
            freq_search_max <= 0;
            ph_inc_current <= (others => '0');
            --ph_inc_reg <= (others => '0');
            gold_sel <= '0';
            ph_inc_load <= '0';
        elsif(rising_edge(clk)) then
            ph_inc_load <= '0';
            case acq_state is
                when WAITING =>
                    if( acq_begin = '1') then
                        acq_state <= PREPARING;
                        time_search_step <= 0;
                        freq_search_step <= 0;
                        freq_search_max <= to_integer(unsigned(phase_inc_count));
                        ph_inc_current <= phase_inc_start;
                        --ph_inc_reg <= phase_inc_step;
                        ph_inc_load <= '1';
                        gold_sel <= '0';
                    end if;
                when PREPARING=>
                    acq_state <= TRIGGERED_WAIT_SOF;
                when TRIGGERED_WAIT_SOF=>
                    if(timing_period_strobe = '1') then
                        acq_state <= ACQUIRING;
                    end if;
                when ACQUIRING =>
                    if(timing_period_strobe = '1') then
                        if(gold_sel = '0') then
                            gold_sel <= '1';
                        else
                            gold_sel <= '0';
                        end if;

                        if(time_search_step = (2**GPS_GOLD_TAPS_WIDTH)-2) then
                            time_search_step <= 0;
                            if(freq_search_step = freq_search_max-1) then
                                --end of freq_search
                                freq_search_step <= 0;
                                acq_state <= WAITING;
                            else
                                freq_search_step <= freq_search_step + 1;
                                ph_inc_current <= std_logic_vector(signed(ph_inc_current) + signed(phase_inc_step));
                                ph_inc_load <= '1';
                            end if;
                        else
                            time_search_step <= time_search_step + 1;
                        end if;
                    end if;

                when others=>
                    acq_state <= WAITING;
            end case;
        end if;
    end process;
end Behavioral;