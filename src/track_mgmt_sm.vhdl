library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity track_mgmt_sm is
    generic(
        OVERSAMPLE_RATIO : integer := 4;
        TRACK_LEN_WIDTH : integer := 2;
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

        trk_en : in std_logic;
        trk_len_slv : in std_logic_vector(TRACK_LEN_WIDTH-1 downto 0); 
        trk_update : in std_logic;
        timing_period_strobe : in std_logic;

        master_timing_slv : in std_logic_vector(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC-1 downto 0); --other 

        time_match: in std_logic_vector(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC-1 downto 0);
        phase_inc: in std_logic_vector(PHASE_INC_WIDTH-1 downto 0);
        sv_test_taps: in std_logic_vector(GPS_GOLD_TAPS_WIDTH-1 downto 0);

        trk_busy : out std_logic;
        
        i_accu_val_e : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);
        q_accu_val_e : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);
        i_accu_val_m : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);
        q_accu_val_m: out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);
        i_accu_val_l : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);
        q_accu_val_l : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);

        reset   : in  std_logic;        
        clk     : in  std_logic
    );
end track_mgmt_sm;

architecture Behavioral of track_mgmt_sm is
    
    type TrkSM_state_type is (WAITING, PREPARING, TRIGGERED_WAIT_SOF, PREROLLING, TRACKING);
    signal trk_state : TrkSM_state_type;

    signal gold_load : std_logic;
    signal gold_sync : std_logic;
    signal gold_ena : std_logic;

    signal time_match_frac : std_logic_vector(MASTER_COUNT_WIDTH_FRAC-1 downto 0);
    signal ph_inc_load :  std_logic;
    signal nco_ena :  std_logic;

    signal accu_sync :  std_logic;
    signal accu_ena  :  std_logic; --general channel enable
    signal accu_sr_ena  :  std_logic; --general channel enable

    component track_complex_correlator_channel is
    generic(
        ACCU_WIDTH : integer := 16;
        ACCU_OUTPUT_WIDTH : integer := 8;
        GPS_GOLD_TAPS_WIDTH : integer := 10;
        PHASE_ACCU_WIDTH : integer := 12;
        PHASE_INC_WIDTH : integer := 8;
        SR_INPUT_SEL_WIDTH : integer := 2;
        SR_DELAY_MAX : integer := 4 --delay for shift register generation, actual length is twice this  for early/late 
    );
    port (
        i_chan : in std_logic;
        q_chan : in std_logic;

        gold_taps_slv : in std_logic_vector(GPS_GOLD_TAPS_WIDTH-1 downto 0);
        gold_load : in std_logic;
        gold_sync : in std_logic;
        gold_ena : in std_logic;

        ph_inc_slv : in  std_logic_vector(PHASE_INC_WIDTH-1 downto 0);
        ph_inc_load : in std_logic;
        nco_reset : in std_logic;
        nco_ena : in std_logic;

        accu_sync : in std_logic;
        accu_ena     : in  std_logic; --general channel enable

        accu_sr_ena :  in  std_logic; --enable the shift register for early/mid/late latching
        accu_sr_sel :  in  std_logic_vector(SR_INPUT_SEL_WIDTH-1 downto 0);

        i_accu_e_val : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);
        q_accu_e_val : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);

        i_accu_m_val : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);
        q_accu_m_val : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);

        i_accu_l_val : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);
        q_accu_l_val : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);

        reset   : in  std_logic;
        
        clk     : in  std_logic
    );
    end component;

begin

    trk_inst : track_complex_correlator_channel
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
            gold_taps_slv => sv_test_taps,
            gold_load => gold_load,
            gold_sync => gold_sync,
            gold_ena => gold_ena,
            
            ph_inc_slv => phase_inc,
            ph_inc_load => ph_inc_load,
            nco_reset => reset,
            nco_ena => nco_ena,
            accu_sync => accu_sync,
            accu_ena  => accu_ena,
            accu_sr_ena => accu_sr_ena,
            accu_sr_sel => "01",
            i_accu_e_val => i_accu_val_e,
            q_accu_e_val => q_accu_val_e,
            i_accu_m_val => i_accu_val_m,
            q_accu_m_val => q_accu_val_m,
            i_accu_l_val => i_accu_val_l,
            q_accu_l_val => q_accu_val_l,
            reset   => reset,
            clk     => clk
        );


    gold_load <= '0';

    process(trk_state)
    begin
        case trk_state is
            when WAITING=>
                trk_busy <= '0';
            when others=>
                trk_busy <= '1';
        end case;
    end process;



    process(trk_state, time_match_frac, master_timing_slv) is
    begin
        case trk_state is
            when PREROLLING | TRACKING=>
                if(time_match_frac = master_timing_slv(MASTER_COUNT_WIDTH_FRAC-1 downto 0)) then
                    gold_ena <= '1';
                    gold_ena <= '1';
                else
                    gold_ena <= '0';
                    gold_ena <= '0';
                end if;
            when others=>
                gold_ena <= '0';
                gold_ena <= '0';
        end case;
    end process;

    process(trk_state, timing_period_strobe, master_timing_slv, time_match) is
    begin
        case trk_state is
            when PREROLLING | TRACKING=>
                if(time_match = master_timing_slv) then
                    gold_sync <= '1';
                else
                    gold_sync <= '0';
                end if;
            when others=>
                gold_sync <= '0';
        end case;
    end process;
    


    process(trk_state) is
    begin
        case trk_state is
            when TRACKING=>
                accu_ena <= '1';
            when others=>
                accu_ena <= '0';
        end case;
    end process;

    process(trk_state) is
    begin
        case trk_state is
            when PREROLLING | TRACKING=>
                accu_sr_ena <= '1';
            when others=>
                accu_sr_ena <= '0';
        end case;
    end process;
    

    process(trk_state) is
    begin
        case trk_state is
            when TRACKING=>
                nco_ena <= '1';
            when others=>
                nco_ena <= '0';
        end case;
    end process;

    process(trk_state,timing_period_strobe) is
    begin
        case trk_state is
            when TRACKING | PREROLLING=>
                accu_sync <= timing_period_strobe;
            when others=>
                accu_sync <= '0';
        end case;
    end process;

    process(clk, reset) is
    begin
        if reset = '1' then
            trk_state <= WAITING;
            time_match_frac <= (others => '0');
            ph_inc_load <= '0';
        elsif(rising_edge(clk)) then
            ph_inc_load <= '0';
            case trk_state is
                when WAITING =>
                    if(trk_en = '1' and trk_update = '1') then
                        trk_state <= PREPARING;
                        --this should set when the (symbol) gold code is updated
                        if(to_integer(unsigned(time_match(MASTER_COUNT_WIDTH_FRAC-1 downto 0))) = 0) then
                            time_match_frac <= std_logic_vector(to_unsigned(OVERSAMPLE_RATIO-1, MASTER_COUNT_WIDTH_FRAC));
                        else
                            time_match_frac <= std_logic_vector(to_unsigned(to_integer(unsigned(time_match(MASTER_COUNT_WIDTH_FRAC-1 downto 0)))-1, MASTER_COUNT_WIDTH_FRAC));
                        end if;
                    end if;
                when PREPARING=>
                    trk_state <= TRIGGERED_WAIT_SOF;
                when TRIGGERED_WAIT_SOF=>
                    if(timing_period_strobe = '1') then
                        trk_state <= PREROLLING;
                    end if;
                when PREROLLING=>
                    if(timing_period_strobe = '1') then
                        trk_state <= TRACKING;
                    end if;
                when TRACKING =>
                    if(trk_update = '1') then
                        if(trk_en = '0') then
                            trk_state <= WAITING;
                        else
                            trk_state <= PREPARING;
                            if(to_integer(unsigned(time_match(MASTER_COUNT_WIDTH_FRAC-1 downto 0))) = 0) then
                                time_match_frac <= std_logic_vector(to_unsigned(OVERSAMPLE_RATIO-1, MASTER_COUNT_WIDTH_FRAC));
                            else
                                time_match_frac <= std_logic_vector(to_unsigned(to_integer(unsigned(time_match(MASTER_COUNT_WIDTH_FRAC-1 downto 0)))-1, MASTER_COUNT_WIDTH_FRAC));
                            end if;
                        end if;                      
                    end if;
                when others=>
                    trk_state <= WAITING;
            end case;
        end if;
    end process;
end Behavioral;