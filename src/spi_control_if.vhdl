library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity spi_control_if is
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
        read_op_data : in std_logic_vector(INPUT_DATA_WIDTH-1 downto 0);

        reset   : in  std_logic;        
        clk     : in  std_logic
    );
end spi_control_if;

architecture Behavioral of spi_control_if is
    constant SYNC_LEN : integer := 2;
    constant SYNC_RESET_LEVEL : std_logic := '1';
    constant SPI_SR_LENGTH : integer := 32;
    constant ADDR_POS : integer :=  8; --read_write make up the first 8 bits
    constant WRITEDATA_POS : integer := 24; --when writing, start acting on the transaction after 24 bits in (leaving 8 clocks for CDC)
    constant READDATA_POS : integer := 8; --when reading, start acting on the transaction after 8 bits in (leaving 8 clocks for CDC)

    component  bit_synchronizer is
    generic (
        STAGES : natural := 2; --# Number of flip-flops in the synchronizer
        RESET_ACTIVE_LEVEL : std_logic := '1' --# Asynch. reset control level
    );
    port (
        Clock  : in std_logic; --# System clock
        Reset  : in std_logic; --# Asynchronous reset

        Bit_in : in std_logic; --# Unsynchronized signal
        Sync   : out std_logic --# Synchronized to Clock's domain
    );
    end component;

    signal spi_dom_write_msg : std_logic_vector(OUTPUT_DATA_WIDTH+ADDR_WIDTH downto 0); --upper bit has read/write
    signal sample_dom_write_msg : std_logic_vector(OUTPUT_DATA_WIDTH+ADDR_WIDTH downto 0); --upper bit has read/write

    signal spi_sr : std_logic_vector(SPI_SR_LENGTH-1 downto 0);
    signal spi_bit_counter : integer range 0 to SPI_SR_LENGTH-1;
    signal spi_write_op : std_logic;

    signal spi_dom_write_op_req : std_logic;
    signal sample_dom_write_op_req : std_logic;
    signal last_sample_dom_write_op_req : std_logic;

    signal sample_dom_write_op_ack : std_logic;
    signal spi_dom_write_op_ack : std_logic;

    signal spi_dom_read_op_req : std_logic;
    signal sample_dom_read_op_req : std_logic;
    signal last_spi_dom_read_op_req : std_logic;

    signal sample_dom_read_op_ack : std_logic;
    signal spi_dom_read_op_ack : std_logic;

    signal sample_dom_op_strobe : std_logic;

begin

    spi_dom_to_sample_dom_write_req :  bit_synchronizer 
    generic map (
        STAGES => SYNC_LEN,
        RESET_ACTIVE_LEVEL => SYNC_RESET_LEVEL
    )
    port map (
        Clock  => clk,
        Reset  => reset,
        Bit_in => spi_dom_write_op_req,
        Sync   => sample_dom_write_op_req
    );

    sample_dom_to_spi_dom_write_ack :  bit_synchronizer 
    generic map (
        STAGES => SYNC_LEN,
        RESET_ACTIVE_LEVEL => SYNC_RESET_LEVEL
    )
    port map (
        Clock  => spi_dom_clk,
        Reset  => spi_dom_csn,
        Bit_in => sample_dom_write_op_ack,
        Sync   => spi_dom_write_op_ack
    );

    spi_dom_to_sample_dom_read_ack :  bit_synchronizer 
    generic map (
        STAGES => SYNC_LEN,
        RESET_ACTIVE_LEVEL => SYNC_RESET_LEVEL
    )
    port map (
        Clock  => clk,
        Reset  => reset,
        Bit_in => spi_dom_read_op_ack,
        Sync   => sample_dom_read_op_ack
    );

    sample_dom_to_spi_dom_read_req :  bit_synchronizer 
    generic map (
        STAGES => SYNC_LEN,
        RESET_ACTIVE_LEVEL => SYNC_RESET_LEVEL
    )
    port map (
        Clock  => spi_dom_clk,
        Reset  => spi_dom_csn,
        Bit_in => sample_dom_read_op_req,
        Sync   => spi_dom_read_op_req
    );


    op_addr <= sample_dom_write_msg(OUTPUT_DATA_WIDTH+ADDR_WIDTH-1 downto OUTPUT_DATA_WIDTH);
    write_op_data <= sample_dom_write_msg(OUTPUT_DATA_WIDTH-1 downto 0);
    sample_dom_op_strobe <= not last_sample_dom_write_op_req and sample_dom_write_op_req; 
    write_op_strobe <= sample_dom_op_strobe and sample_dom_write_msg(OUTPUT_DATA_WIDTH+ADDR_WIDTH);
    read_op_req <= sample_dom_op_strobe and not sample_dom_write_msg(OUTPUT_DATA_WIDTH+ADDR_WIDTH);


    spi_dom_write_msg <= spi_sr(7) & spi_sr(ADDR_WIDTH-1 downto 0) & x"0000" when spi_write_op = '0' else
                         spi_sr(23) & spi_sr(OUTPUT_DATA_WIDTH+ADDR_WIDTH-1 downto OUTPUT_DATA_WIDTH) & spi_sr(OUTPUT_DATA_WIDTH-1 downto 0);

    sample_dom_write_msg <= spi_dom_write_msg;

    --process for sample clock handshaking
    process(clk, reset) is
    begin
        if(reset = '1') then
            sample_dom_write_op_ack <= '0';
            sample_dom_read_op_req <= '0';
            last_sample_dom_write_op_req <= '0';
        elsif(rising_edge(clk)) then
            --spi domain write operation handshaking
            if(sample_dom_read_op_ack = '1') then --ack has come back, deassert the request.
                sample_dom_read_op_req <= '0';
            end if;
            if(sample_dom_read_op_req = '0') then            
                if(read_update_strobe = '1') then
                    sample_dom_read_op_req <= '1';
                end if;
            end if;

            --sample domain write_operation handshaking
            last_sample_dom_write_op_req <= sample_dom_write_op_req;

            if(sample_dom_write_op_ack = '1') then
                if(sample_dom_write_op_req = '0') then
                    sample_dom_write_op_ack <= '0';
                end if;
            else
                if(sample_dom_write_op_req = '1') then
                    sample_dom_write_op_ack <= '1';
                end if;
            end if;
        end if;
    end process;

    --process for managing spi side handshaking
    process(spi_dom_clk, spi_dom_csn) is
    begin
        if(spi_dom_csn = '1') then
            spi_dom_write_op_req <= '0';
            spi_dom_read_op_ack <= '0';
            last_spi_dom_read_op_req <= '0';
        elsif(rising_edge(spi_dom_clk)) then
            --spi domain write operation handshaking
            if(spi_dom_write_op_ack = '1') then --ack has come back, deassert the request.
                spi_dom_write_op_req <= '0';
            end if;
            if(spi_dom_write_op_req = '0') then            
                if(spi_bit_counter = READDATA_POS) then --we're at bit 8, start a read operation, so we have the data by bit 16 for clocking out
                    if(spi_write_op = '0') then
                        spi_dom_write_op_req <= '1';
                    end if;
                elsif(spi_bit_counter = WRITEDATA_POS) then --we're at bit 24 and have all we need for write operation, use 8 bits for actioning
                    if(spi_write_op = '1') then
                        spi_dom_write_op_req <= '1';
                    end if;
                end if;
            end if;

            --spi domain read_operation handshaking
            last_spi_dom_read_op_req <= spi_dom_read_op_req;
            if(spi_dom_read_op_ack = '1') then
                if(spi_dom_read_op_req = '0') then
                    spi_dom_read_op_ack <= '0';
                end if;
            else
                if(spi_dom_read_op_req = '1') then
                    spi_dom_read_op_ack <= '1';
                end if;
            end if;
        end if;
    end process;

    --output SR data process
    process(spi_dom_clk, spi_dom_csn) is
    begin
        if(spi_dom_csn = '1') then
            spi_dom_miso <= spi_dom_mosi;
        elsif(falling_edge(spi_dom_clk)) then
            --clock out the right bits
            if(spi_bit_counter <= READDATA_POS-1) then
                 spi_dom_miso <= spi_dom_mosi;
            elsif(spi_bit_counter >= INPUT_DATA_WIDTH-1) then
                spi_dom_miso <= spi_sr(SPI_SR_LENGTH-1);
            else
                spi_dom_miso <= '0';
            end if;
        end if;
    end process;


    --spi dom clock process
    process(spi_dom_clk, spi_dom_csn) is
    begin
        if(spi_dom_csn = '1') then
            spi_sr <= (others => '0');
            spi_bit_counter <= 0;
            spi_write_op <= '0';
        elsif(rising_edge(spi_dom_clk)) then
            if(spi_bit_counter = 0) then
                if(spi_dom_mosi = '1') then
                    spi_write_op <= '1';
                else
                    spi_write_op <= '0';
                end if;
            end if;
            --sr advance logic
            --advance for the first bit (before we know read or write)
            --if we're reading, advance for the first byte (so we know the address) --then clock back the last 16 bit to feed back the output data msb to lsb
            --if we're writing, advance until all the write data has been accepted
            if(spi_bit_counter = 0 or (spi_write_op = '1' and spi_bit_counter <= WRITEDATA_POS-1) or (spi_write_op = '0' and ((spi_bit_counter <= READDATA_POS-1) or (spi_bit_counter >= INPUT_DATA_WIDTH-1)))) then
                spi_sr <= spi_sr(SPI_SR_LENGTH-2 downto 0) & spi_dom_mosi;
            end if;


            if(spi_bit_counter = SPI_SR_LENGTH-1) then --last bit
                spi_bit_counter <= 0;
            else
                spi_bit_counter <= spi_bit_counter + 1;
            end if;

            if(spi_dom_read_op_req = '1' and last_spi_dom_read_op_req = '0') then
                --latch sr data on first clock of read op request.
                spi_sr(SPI_SR_LENGTH-1 downto SPI_SR_LENGTH-INPUT_DATA_WIDTH) <= read_op_data;
            end if;
        end if;
    end process;
end Behavioral;