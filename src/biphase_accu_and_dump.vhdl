library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity biphase_accu_and_dump is
    generic(
        ACCU_WIDTH : integer := 16;
        ACCU_OUTPUT_WIDTH : integer := 8;
        ACCU_MIN_INT : integer := -1*(2**(ACCU_WIDTH-1));
        ACCU_MAX_INT : integer := (2**(ACCU_WIDTH-1)-1)
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
end biphase_accu_and_dump;

architecture Behavioral of biphase_accu_and_dump is
    signal accu_val : integer range ACCU_MIN_INT to ACCU_MAX_INT;
    signal accu_val_reg : std_logic_vector(ACCU_WIDTH-1 downto 0);
begin
    
    accu_reg_data <= accu_val_reg(ACCU_WIDTH-1 downto ACCU_WIDTH-ACCU_OUTPUT_WIDTH);

    process(clk) is
        variable new_accu_val : integer range ACCU_MIN_INT to ACCU_MAX_INT;
    begin
        if(rising_edge(clk)) then
            if((inc_input and dec_input) = '0') then -- check they are not both 1
                if(inc_input = '1') then
                    if(accu_val < ACCU_MAX_INT) then --check for upper wrapping and saturate
                        new_accu_val := accu_val + 1;
                    else
                        new_accu_val := accu_val;
                    end if;
                elsif(dec_input = '1') then
                    if(accu_val > ACCU_MIN_INT) then
                        new_accu_val := accu_val -1; -- check for lower wrapping and saturate
                    else
                        new_accu_val := accu_val;
                    end if;
                else
                    new_accu_val := accu_val; 
                end if;
            else
                new_accu_val := accu_val;
            end if;

            if(reset = '1') then
                accu_val <= 0;
                accu_val_reg <= (others => '0');
            elsif(accu_sync = '1') then
                accu_val_reg <= std_logic_vector(to_signed(new_accu_val, ACCU_WIDTH));
                accu_val <= 0;
            elsif(ena = '1') then
                accu_val <= new_accu_val;
            end if;
        end if;
    end process;
end Behavioral;