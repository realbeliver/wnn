library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity gold_code_gen is
    generic(
        WIDTH : integer := 10;
        G1_TAPS : std_logic_vector(WIDTH-2 downto 0) := "000000100";
        G2_TAPS : std_logic_vector(WIDTH-2 downto 0) := "110100110" --not including 10th bit always fed back
    );
    port (
        sv_taps : in  std_logic_vector(WIDTH-1 downto 0); --array of taps to use for G2 delays, registe
        sv_load : in  std_logic;
        gold_code_out  : out std_logic;
        ena     : in  std_logic;
        clk     : in  std_logic;
        reset   : in  std_logic;
        sync   : in  std_logic
    );
end gold_code_gen;

architecture Behavioral of gold_code_gen is
    signal g1_sr : std_logic_vector(WIDTH-1 downto 0);
    signal g2_sr : std_logic_vector(WIDTH-1 downto 0);
    signal g1_fb : std_logic;
    signal g2_fb : std_logic;
    signal g1_tapped : std_logic;
    signal sv_tapped : std_logic;
    --signal sv_taps_reg : std_logic_vector(WIDTH-1 downto 0);
begin
    gold_code_out <= g1_tapped xor sv_tapped;
    g1_tapped <= g1_sr(0);

    process(g1_sr, g2_sr) is
        variable g1_fb_int: std_logic;
        variable g2_fb_int: std_logic;
        variable sv_tapped_int : std_logic;
    begin
        g1_fb_int := g1_sr(0); -- always feedback the last (longest sr bit)
        g2_fb_int := g2_sr(0);
        for i in 0 to WIDTH-2 loop
            g1_fb_int := g1_fb_int xor (g1_sr(WIDTH-1-i) and G1_TAPS(i));
            g2_fb_int := g2_fb_int xor (g2_sr(WIDTH-1-i) and G2_TAPS(i));
        end loop;
        g1_fb <= g1_fb_int;
        g2_fb <= g2_fb_int;

        sv_tapped_int := '0';
        for j in 0 to WIDTH-1 loop
            sv_tapped_int := sv_tapped_int xor (g2_sr(WIDTH-1-j) and sv_taps(j));
        end loop;
        sv_tapped <= sv_tapped_int;
    end process;

    process(clk, reset) is
    begin
        if(reset = '1') then
            g1_sr <= (others => '1');
            g2_sr <= (others => '1');
            --sv_taps_reg <= (others => '0');
        elsif(rising_edge(clk)) then           
            -- if(sv_load = '1') then
            --     sv_taps_reg <= sv_taps;
            -- end if;

            if(sync = '1') then
                g1_sr <= (others => '1');
                g2_sr <= (others => '1');
            elsif (ena = '1') then
                g1_sr <= g1_fb & g1_sr(WIDTH-1 downto 1);
                g2_sr <= g2_fb & g2_sr(WIDTH-1 downto 1);
            end if;
        end if;

    end process;

end Behavioral;