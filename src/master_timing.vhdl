library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity master_timing is
    generic(
        OSAMP_RATIO : integer := 4;
        MASTER_COUNT_WIDTH_INT : integer := 10;
        MASTER_COUNT_WIDTH_FRAC : integer := 2;
        MAX_COUNT_INT : integer := 1023
    );
    port (
        master_clock_count : out std_logic_vector(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC-1 downto 0);
        timing_sof  : out std_logic;
        ena     : in  std_logic;
        clk     : in  std_logic;
        reset   : in  std_logic
    );
end master_timing; 

architecture Behavioral of master_timing is
    signal counter : integer range 0 to (2**(MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC))-1;
begin

    timing_sof <= '1' when counter = ((MAX_COUNT_INT*OSAMP_RATIO)-1) else '0';
    master_clock_count <= std_logic_vector(to_unsigned(counter, MASTER_COUNT_WIDTH_INT+MASTER_COUNT_WIDTH_FRAC));

    process(clk, reset) is
    begin   
        if(reset = '1') then
            counter <= 0;
        elsif(rising_edge(clk)) then
            if(ena = '1') then
                if(counter = (MAX_COUNT_INT*OSAMP_RATIO)-1) then
                    counter <= 0;
                else
                    counter <= counter + 1;
                end if;
            end if;
        end if;
    end process;
end Behavioral;