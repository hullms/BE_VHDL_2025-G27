library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity clock_management is
  port (
    clk50    : in  std_logic;   -- 50 MHz
    reset_n  : in  std_logic;   -- reset asynchrone actif bas
    clk_10k  : out std_logic;   -- ~10 kHz, duty ~50%
    clk_1hz  : out std_logic;   -- ~1 Hz, duty ~50%
    tick_1hz : out std_logic    -- impulsion 1 cycle (clk_10k domain) à chaque front montant de clk_1hz
  );
end entity;

architecture rtl of clock_management is
  signal div10k_q : unsigned(12 downto 0) := (others=>'0'); -- 0..2499 → 10 kHz
  signal div1hz_q : unsigned(23 downto 0) := (others=>'0'); -- 0..4999 → 1 Hz
  signal clk10k_q : std_logic := '0';
  signal clk1hz_q : std_logic := '0';

  signal clk1hz_meta, clk1hz_sync, clk1hz_sync_d : std_logic := '0';
begin
  -- ÷ pour 10 kHz depuis 50 MHz
  process(clk50, reset_n)
  begin
    if reset_n='0' then
      div10k_q <= (others=>'0');
      clk10k_q <= '0';
    elsif rising_edge(clk50) then
      if div10k_q = to_unsigned(2499, div10k_q'length) then
        div10k_q <= (others=>'0');
        clk10k_q <= not clk10k_q;
      else
        div10k_q <= div10k_q + 1;
      end if;
    end if;
  end process;

  clk_10k <= clk10k_q;

  -- ÷ pour 1 Hz depuis 10 kHz
  process(clk10k_q, reset_n)
  begin
    if reset_n='0' then
      div1hz_q <= (others=>'0');
      clk1hz_q <= '0';
    elsif rising_edge(clk10k_q) then
      if div1hz_q = to_unsigned(4999, div1hz_q'length) then
        div1hz_q <= (others=>'0');
        clk1hz_q <= not clk1hz_q;
      else
        div1hz_q <= div1hz_q + 1;
      end if;
    end if;
  end process;

  clk_1hz <= clk1hz_q;

  -- tick_1hz : impulsion courte à chaque front montant du 1 Hz
  process(clk10k_q, reset_n)
  begin
    if reset_n='0' then
      clk1hz_meta   <= '0';
      clk1hz_sync   <= '0';
      clk1hz_sync_d <= '0';
    elsif rising_edge(clk10k_q) then
      clk1hz_meta   <= clk1hz_q;
      clk1hz_sync   <= clk1hz_meta;
      clk1hz_sync_d <= clk1hz_sync;
    end if;
  end process;

  tick_1hz <= clk1hz_sync and (not clk1hz_sync_d);

end architecture;
