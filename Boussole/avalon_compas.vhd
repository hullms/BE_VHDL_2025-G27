library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity avalon_compas is
  port (
    clk, chipselect, write_n, reset_n : in std_logic;
		writedata : in std_logic_vector (31 downto 0);
		readdata : out std_logic_vector (31 downto 0);
		address: in std_logic;
		pwm_compas : in std_logic
  );
end entity;

architecture rtl of avalon_compas is
  signal clk50, clk_10k, clk_1hz, tick_1hz, raz_n : std_logic;
  signal enable, done, continu, start_stop, data_valide : std_logic;
  signal angle     : unsigned(8 downto 0);
  signal mode_q       : std_logic := '0';
   signal config : std_logic_vector (2 downto 0);
begin
  clk50 <= clk;
  -- Horloges
  u_clk: entity work.clock_management
    port map (
      clk50    => clk50,
      reset_n  => reset_n,
      clk_10k  => clk_10k,
      clk_1hz  => clk_1hz,
      tick_1hz => tick_1hz
    );

  -- Mode continu / mono
  process(clk_10k, reset_n)
  begin
    if reset_n='0' then
      enable <= '0';
      data_valide <= '0';
    elsif rising_edge(clk_10k) then
      enable <= '0';
      data_valide <= '0';
      if continu='1' then
        if tick_1hz='1' then enable <= '1'; end if;
        if done='1' then data_valide <= '1'; end if;
      else
        if start_stop='0' then enable <= '1'; end if;
        if done='1' then data_valide <= '1'; end if;
      end if;
    end if;
  end process;
raz_n <= config(0);
continu <= config(1);
start_stop <= config(2);
  -- Calcul d'angle
  u_angle: entity work.angle_calcul
    port map(
      clk_10k  => clk_10k,
      reset_n  => reset_n,
      enable   => enable,
      pwm_in   => pwm_compas,
      angle    => angle,
      done     => done
    );



registers: process (clk, reset_n)
begin
	if reset_n = '0' then
	config <= (others => '0');
	elsif clk'event and clk = '1' then
		if chipselect ='1' and write_n = '0' then
			if address = '0' then
			config <= (writedata (2 downto 0));
			end if;
		end if;
	end if;
end process registers;
--*******************************************************   
-- Lecture registres
--*******************************************************  
readdata <= (X"0000000" & "0"  & config)  when address = '0' else
  (X"00000"   & "00" & data_valide & std_logic_vector(angle));
	
end architecture rtl;