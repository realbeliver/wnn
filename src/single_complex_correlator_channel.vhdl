library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity single_complex_correlator_channel is
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

        i_accu_val : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);
        q_accu_val : out std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0);


        reset   : in  std_logic;
        
        clk     : in  std_logic
    );
end single_complex_correlator_channel;

architecture Behavioral of single_complex_correlator_channel is
    component gold_code_gen is
    generic(
        WIDTH : integer := 10
    );
    port (
        sv_taps : in  std_logic_vector(WIDTH-1 downto 0); --array of taps to use for G2 delays, registe
        sv_load : in  std_logic;
        gold_code_out  : out std_logic;
        ena     : in  std_logic;
        clk     : in  std_logic;
        sync   : in  std_logic
    );
    end component;

    component biphase_accu_and_dump is
    generic(
        ACCU_WIDTH : integer := 16;
        ACCU_OUTPUT_WIDTH : integer := 8
    );
    port (
        inc_input : in std_logic; --high indicates increment request
        dec_input : in std_logic; --high indicates decrement request
        accu_reg_data : out  std_logic_vector(ACCU_OUTPUT_WIDTH-1 downto 0); --signed output from accumulator
        accu_sync : in  std_logic; -- clear count and register the current count val
        ena     : in  std_logic;
        clk     : in  std_logic;
        reset   : in  std_logic
    );
    end component;

    component bidir_complex_nco_1b is
    generic(
        ACCU_WIDTH : integer := 12;
        INC_WIDTH : integer := 8
    );
    port (
        ph_inc_val : in  std_logic_vector(INC_WIDTH-1 downto 0); --phase increment value signed input
        ph_load : in  std_logic;
        nco_out_i  : out std_logic;
        nco_out_q  : out std_logic;
        ena     : in  std_logic;
        clk     : in  std_logic;
        reset   : in  std_logic
    );
    end component; 

    signal reference_gold_code : std_logic;
    signal i_nco_output : std_logic;
    signal q_nco_output : std_logic;
    signal i_reference_mixed_nco : std_logic;
    signal q_reference_mixed_nco : std_logic;
    signal i_corl_iphase : std_logic; --in phase (increment the accus)
    signal i_corl_ophase : std_logic; --out of phase (decrement the accus)
    signal q_corl_iphase : std_logic;
    signal q_corl_ophase : std_logic;
begin

    --mixing stuff here, declare with when rather than xor to allow a more easy interpetation
    --for i and q channels, 1 = 1 and 0 = -1
    i_reference_mixed_nco <= '1' when (reference_gold_code = '1' and i_nco_output = '1') or (reference_gold_code = '0' and i_nco_output = '0') else '0';
    q_reference_mixed_nco <= '1' when (reference_gold_code = '1' and q_nco_output = '1') or (reference_gold_code = '0' and q_nco_output = '0') else '0';

    i_corl_iphase <= '1' when (i_chan = '1' and i_reference_mixed_nco = '1') else '0';
    i_corl_ophase <= '1' when (i_chan = '0' and i_reference_mixed_nco = '0') else '0';

    q_corl_iphase <= '1' when (q_chan = '1' and q_reference_mixed_nco = '1') else '0';
    q_corl_ophase <= '1' when (q_chan = '0' and q_reference_mixed_nco = '0') else '0';


    gold_gen : gold_code_gen  
        generic map (
            WIDTH => GPS_GOLD_TAPS_WIDTH
        )
        port map(
            sv_taps => gold_taps_slv,
            sv_load => gold_load,
            gold_code_out  => reference_gold_code,
            ena    => gold_ena,
            clk    => clk,
            sync   => gold_sync
        );

    complex_nco : bidir_complex_nco_1b
        generic map (
            ACCU_WIDTH => PHASE_ACCU_WIDTH,
            INC_WIDTH => PHASE_INC_WIDTH
        )
        port map (
            ph_inc_val => ph_inc_slv,
            ph_load => ph_inc_load,
            nco_out_i => i_nco_output,
            nco_out_q => q_nco_output,
            ena     => nco_ena,
            clk     => clk,
            reset   => nco_reset
        );
    
    accu_i_chan : biphase_accu_and_dump
        generic map(
            ACCU_WIDTH => ACCU_WIDTH
        )
        port map (
            inc_input => i_corl_iphase,
            dec_input => i_corl_ophase,
            accu_reg_data => i_accu_val,
            accu_sync => accu_sync,
            ena     => accu_ena,
            clk     => clk,
            reset   => reset
        );

    accu_q_chan : biphase_accu_and_dump
        generic map(
            ACCU_WIDTH => ACCU_WIDTH
        )
        port map (
            inc_input => q_corl_iphase,
            dec_input => q_corl_ophase,
            accu_reg_data => q_accu_val,
            accu_sync => accu_sync,
            ena     => accu_ena,
            clk     => clk,
            reset   => reset
        );
    
end Behavioral;