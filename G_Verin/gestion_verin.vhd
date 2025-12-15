library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all; 

entity gestion_verin is 
    port
    (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        chipselect  : in  std_logic;
        write_n     : in  std_logic;
        address     : in  std_logic_vector(2 downto 0);
        writedata   : in  std_logic_vector(31 downto 0);
        readdata    : out std_logic_vector(31 downto 0);
        data_in     : in  std_logic;
        out_pwm     : out std_logic;
        out_sens    : out std_logic;
        cs_n        : out std_logic;
        clk_adc     : out std_logic
    );
end gestion_verin;

architecture avalon_gestion_verin of  gestion_verin is 
    signal s_freq       : std_logic_vector(15 downto 0); -- Reg 0
    signal s_duty       : std_logic_vector(15 downto 0); -- Reg 1
    signal s_butee_g    : std_logic_vector(11 downto 0); -- Reg 2
    signal s_butee_d    : std_logic_vector(11 downto 0); -- Reg 3
    signal s_config     : std_logic_vector(2 downto 0);  -- Reg 4 (bits 0,1,2 en écriture)
    signal s_rst_n : std_logic;
    signal s_enable     : std_logic;
    signal s_sens       : std_logic;
    signal cpt_pwm      : unsigned(15 downto 0);
    signal s_pwm_brut   : std_logic;
    signal s_fin_course_d : std_logic;
    signal s_fin_course_g : std_logic;
    signal s_angle_barre  : std_logic_vector(11 downto 0); -- Reg 5
    signal s_clk_1M       : std_logic := '0';
    signal s_tick_montant : std_logic := '0';
    signal s_start_conv   : std_logic := '0';
    signal s_cs_n         : std_logic := '1';
    signal s_cpt_bits     : integer range 0 to 31 := 0;
    signal s_shift_reg    : std_logic_vector(14 downto 0) := (others => '0');
    type t_etat is (IDLE, CONVERSION, MEMORISATION);
    signal etat_present   : t_etat;

BEGIN

    s_rst_n      <= s_config(0);
    s_enable     <= s_config(1);
    s_sens       <= s_config(2);

    -- 1. BLOC PWM
    divide: process (clk, reset_n)
    begin
        if reset_n = '0' then
            cpt_pwm <= (others => '0');
        elsif rising_edge(clk) then
            if cpt_pwm >= unsigned(s_freq) then
                cpt_pwm <= (others => '0');
            else
                cpt_pwm <= cpt_pwm + 1;
            end if;
        end if;
    end process divide;    

    compare: process (clk, reset_n)
    begin
        if reset_n = '0' then
            s_pwm_brut <= '0';
        elsif rising_edge(clk) then
            if cpt_pwm >= unsigned(s_duty) then
                s_pwm_brut <= '0';
            else
                s_pwm_brut <= '1';
            end if;
        end if;
    end process compare;
	 
    --BLOC CONTRÔLE BUTÉES
    process(s_angle_barre, s_butee_d, s_butee_g)
    begin
        if unsigned(s_angle_barre) >= unsigned(s_butee_d) then
            s_fin_course_d <= '1';
        else 
            s_fin_course_d <= '0';
        end if;
        
        if unsigned(s_angle_barre) <= unsigned(s_butee_g) then
            s_fin_course_g <= '1';
        else
            s_fin_course_g <= '0';
        end if;
    end process;

    -- Sécurité PWM (Utilisation des signaux décomposés)
    out_pwm <= '1' when (s_enable = '1' and s_pwm_brut = '1' and (
                            (s_sens = '1' and s_fin_course_d = '0') or 
                            (s_sens = '0' and s_fin_course_g = '0')
                        )) else '0';

    out_sens <= s_sens;

    -- 3. BLOC ADC
    clk_adc <= s_clk_1M;
    cs_n    <= s_cs_n;

    gene_1M : process(clk, reset_n)
        variable cpt : integer range 0 to 24 := 0;
    begin
        if reset_n = '0' then
            cpt := 0;
            s_clk_1M <= '0';
            s_tick_montant <= '0';
        elsif rising_edge(clk) then
            s_tick_montant <= '0';
            if cpt = 24 then
                s_clk_1M <= not s_clk_1M;
                cpt := 0;
                if s_clk_1M = '0' then
                    s_tick_montant <= '1';
                end if;
            else
                cpt := cpt + 1;
            end if;
        end if;
    end process gene_1M;

    gene_start_conv : process(clk, reset_n)
        variable cpt_temps : integer range 0 to 5000000 := 0;
    begin
        if reset_n = '0' then
            cpt_temps := 0;
            s_start_conv <= '0';
        elsif rising_edge(clk) then
            if cpt_temps = 4999999 then
                s_start_conv <= '1';
                cpt_temps := 0;
            else
                s_start_conv <= '0';
                cpt_temps := cpt_temps + 1;
            end if;
        end if;
    end process gene_start_conv;

    pilote_adc : process(clk, reset_n)
    begin
        if reset_n = '0' then
            etat_present <= IDLE;
            s_cs_n <= '1';
            s_angle_barre <= (others => '0');
        elsif rising_edge(clk) then
            case etat_present is
                when IDLE =>
                    s_cs_n <= '1';
                    if s_start_conv = '1' then
                        etat_present <= CONVERSION;
                    end if;
                when CONVERSION =>
                    s_cs_n <= '0';
                    if s_cpt_bits >= 16 then
                        etat_present <= MEMORISATION;
                    end if;
                when MEMORISATION =>
                    s_cs_n <= '1';
                    s_angle_barre <= s_shift_reg(11 downto 0); 
                    etat_present <= IDLE;
            end case;
        end if;
    end process pilote_adc;

    compt_fronts : process(clk, reset_n)
    begin
        if reset_n = '0' then
            s_cpt_bits <= 0;
        elsif rising_edge(clk) then
            if etat_present = IDLE then
                s_cpt_bits <= 0;
            elsif etat_present = CONVERSION then
                if s_tick_montant = '1' then
                    s_cpt_bits <= s_cpt_bits + 1;
                end if;
            end if;
        end if;
    end process compt_fronts;

    rec_dec : process(clk, reset_n)
    begin
        if reset_n = '0' then
            s_shift_reg <= (others => '0');
        elsif rising_edge(clk) then
            if etat_present = CONVERSION and s_tick_montant = '1' then
                s_shift_reg <= s_shift_reg(13 downto 0) & data_in;
            end if;
        end if;
    end process rec_dec;

    -- 4. INTERFACE AVALON
    process_write: process (clk, reset_n)
    begin
        if reset_n = '0' then
            s_freq    <= (others => '0');
            s_duty    <= (others => '0');
            s_butee_g <= (others => '0');
            s_butee_d <= (others => '0');
            s_config  <= (others => '0');
        elsif rising_edge(clk) then
            if chipselect = '1' and write_n = '0' then
                case address is
                    when "000" => s_freq    <= writedata(15 downto 0); -- Reg 0
                    when "001" => s_duty    <= writedata(15 downto 0); -- Reg 1
                    when "010" => s_butee_g <= writedata(11 downto 0); -- Reg 2
                    when "011" => s_butee_d <= writedata(11 downto 0); -- Reg 3
                    when "100" => s_config  <= writedata(2 downto 0);  -- Reg 4 (Direct)
                    when others => null;
                end case;
            end if;
        end if;
    end process process_write;

    process_read: process(address, s_angle_barre, s_freq, s_duty, s_butee_g, s_butee_d, s_config, s_fin_course_d, s_fin_course_g)
    begin
        readdata <= (others => '0'); 
        
        case address is
            when "000" => readdata(15 downto 0) <= s_freq;
            when "001" => readdata(15 downto 0) <= s_duty;
            when "010" => readdata(11 downto 0) <= s_butee_g;
            when "011" => readdata(11 downto 0) <= s_butee_d;
            when "100" => 
                readdata(2 downto 0) <= s_config;
                readdata(3) <= s_fin_course_d;
                readdata(4) <= s_fin_course_g;
            when "101" => readdata(11 downto 0) <= s_angle_barre; 
            when others => readdata <= (others => '0');
        end case;
    end process process_read;

end architecture;