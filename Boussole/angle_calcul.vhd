library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity angle_calcul is
  port (
    clk_10k   : in  std_logic;
    reset_n   : in  std_logic;
    enable    : in  std_logic;
    pwm_in    : in  std_logic;
    angle     : out unsigned(8 downto 0); -- 0..360
    done      : out std_logic              -- pulse 1 cycle
  );
end entity;

architecture rtl of angle_calcul is
  signal pwm_meta, pwm_sync, pwm_sync_d : std_logic := '0';
  signal rising_pwm, falling_pwm : std_logic;
  type state_t is (SUSPENDED, READY, INIT, TICK_CNT, ENDED);
  signal s, ns : state_t := SUSPENDED;
  signal cnt, angle_q : unsigned(8 downto 0) := (others=>'0');
  signal done_q : std_logic := '0';
begin
  -- Synchronisation du PWM
  process(clk_10k, reset_n)
  begin
    if reset_n='0' then
      pwm_meta   <= '0';
      pwm_sync   <= '0';
      pwm_sync_d <= '0';
    elsif rising_edge(clk_10k) then
      pwm_meta   <= pwm_in;
      pwm_sync   <= pwm_meta;
      pwm_sync_d <= pwm_sync;
    end if;
  end process;

  rising_pwm  <= (not pwm_sync_d) and pwm_sync;
  falling_pwm <= pwm_sync_d and (not pwm_sync);

  -- FSM + compteur
  process(clk_10k, reset_n)
  begin
    if reset_n='0' then
      s      <= SUSPENDED;
      cnt    <= (others=>'0');
      angle_q<= (others=>'0');
      done_q <= '0';
    elsif rising_edge(clk_10k) then
      s      <= ns;
      done_q <= '0';
      case s is
        when SUSPENDED => cnt <= (others=>'0');
        when READY     => null;
        when INIT      => cnt <= (others=>'0');
        when TICK_CNT  =>
          if pwm_sync='1' then
            if cnt < to_unsigned(370, cnt'length) then
              cnt <= cnt + 1;
            else
              cnt <= to_unsigned(370, cnt'length);
            end if;
          end if;
        when ENDED =>
          if cnt > to_unsigned(10, cnt'length) then
            angle_q <= cnt - 10;
          else
            angle_q <= (others=>'0');
          end if;
          done_q <= '1';
      end case;
    end if;
  end process;

  -- Logique d'états
  process(s, enable, pwm_sync, rising_pwm, falling_pwm)
  begin
    ns <= s;
    case s is
      when SUSPENDED =>
        if enable='1' then ns <= READY; end if;
      when READY =>
        if pwm_sync='0' then ns <= INIT; end if;
      when INIT =>
        if rising_pwm='1' then ns <= TICK_CNT; end if;
      when TICK_CNT =>
        if falling_pwm='1' then ns <= ENDED; end if;
      when ENDED =>
        ns <= SUSPENDED;
    end case;
  end process;

  angle <= angle_q;
  done  <= done_q;
end architecture;
