library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bidir_complex_nco_1b is
    generic(
        ACCU_WIDTH : integer := 12;
        INC_WIDTH : integer := 8;
        RESET_VAL : integer := 0;
        ACCU_MIN_INT : integer := -1*(2**(ACCU_WIDTH-1));
        ACCU_MAX_INT : integer := (2**(ACCU_WIDTH-1)-1);
        ACCU_LMID_INT : integer := -1*(2**(ACCU_WIDTH-2));
        ACCU_HMID_INT : integer := (2**(ACCU_WIDTH-2)-1)
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
end bidir_complex_nco_1b; 

architecture Behavioral of bidir_complex_nco_1b is
    signal phase_accu : integer range ACCU_MIN_INT to ACCU_MAX_INT;
    signal ph_inc_int : integer range ACCU_MIN_INT to ACCU_MAX_INT;
    --signal phase_inc_reg : std_logic_vector(INC_WIDTH-1 downto 0);
begin

    process(phase_accu) is
    begin
        if(phase_accu >= 0) then
            nco_out_q <= '1'; --treat as sin part, cos + i sin (theta), sine is positive for all positive values from 0 to +pi
        else
            nco_out_q <= '0'; --treat as sin part, sine is negative for all neg values from 0 to -pi
        end if;

        if((phase_accu >= ACCU_LMID_INT) and (phase_accu <= ACCU_HMID_INT)) then
            nco_out_i <= '1'; --treat as cos part, cos(theta) + i sin(theta) cos is positive for -pi/2 to +pi/2
        else
            nco_out_i <= '0';
        end if;
    end process;

    ph_inc_int <= to_integer(signed(ph_inc_val));

    process(clk, reset) is
    begin
        if(reset = '1') then
            phase_accu <= RESET_VAL;
                --phase_inc_reg <= (others => '0');
        elsif(rising_edge(clk)) then
            if(ph_load = '1') then
                --phase_inc_reg <= ph_inc_val;
                phase_accu <= RESET_VAL;
            elsif(ena = '1') then
                --increment the phase register and handle wrapping
                
                if(ph_inc_int >= 0) then
                    if(phase_accu + ph_inc_int < ACCU_MAX_INT) then
                        phase_accu <= phase_accu + ph_inc_int;
                    else
                        phase_accu <= ACCU_MIN_INT + (phase_accu + ph_inc_int - ACCU_MAX_INT);
                    end if;
                else
                    if(phase_accu + ph_inc_int > ACCU_MIN_INT) then
                       phase_accu <= phase_accu + ph_inc_int;
                    else
                       phase_accu <= ACCU_MAX_INT + (phase_accu + ph_inc_int + ACCU_MAX_INT);
                    end if;
                end if;
            end if;
        end if;
    end process;
end Behavioral;