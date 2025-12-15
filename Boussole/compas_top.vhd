library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity compas_top is
  port (
    clk50       : in  std_logic;
    reset_n     : in  std_logic;
    continu     : in  std_logic;
    start_stop  : in  std_logic;
    pwm_compas  : in  std_logic;
    angle_deg   : out unsigned(8 downto 0);
    data_valide : out std_logic
  );
end entity;

architecture rtl of compas_top is
  signal clk_10k, clk_1hz, tick_1hz : std_logic;
  signal enable, done : std_logic;
  signal angle        : unsigned(8 downto 0);
  signal mode_q       : std_logic := '0';
begin
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

  angle_deg <= angle;

end architecture;
