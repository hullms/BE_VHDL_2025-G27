library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity avalon_anemometre is 
PORT
	(
	 -- entrées externes 
	 clk: in std_logic ;
	 reset_n : in std_logic ; -- reset global 
	 in_freq_anemometre : in std_logic; -- 0 <= in_freq <= 250
	 
	 -- pour le bus avalon 
	 write_n : in std_logic; -- 0 pour écrire dans l'anemo, 1 pour lire 
	 chipselect : in std_logic; -- sélectionner l'anemo
	 writedata : in std_logic_vector (31 downto 0); -- le NIOS écrit ses instructions içi
	 readdata : out std_logic_vector (31 downto 0); -- le NIOS lit d'aprés ces valeurs 
	 address : in std_logic-- pour choisir entre les registres config ou code 
	 );
end avalon_anemometre;
 
architecture archAvanemometre of avalon_anemometre is
signal data_anemometre :std_logic_vector( 7 downto 0); 
signal start_stop : std_logic; -- 1 lancer la mesure, 0 arrêter
signal continue : std_logic;  -- pour choisir le mode : 0 monocoup , 1 continue 
signal data_valid: std_logic; -- 1 si la donnée est valide 
Signal start_mesur : std_logic := '0';
Signal compt_freq : integer range 0 to 250 := 0;
Signal mesure_value : integer range 0 to 250 := 0;
signal raz_n : std_logic := '0'; -- rst logiciel par le NIOS
begin 

-- process pour créer une fenêtre de mesure de 1s 
process (clk,reset_n,raz_n) 
variable compt_time : integer range 0 to 100000000:= 0;
begin 
	if(reset_n = '0' OR raz_n = '1' ) then 
		compt_time := 0;
	elsif(rising_edge(clk)) then 
		compt_time := compt_time +1 ;
		if(compt_time <= 50000000) then 
			start_mesur <= '1';
		else 
			start_mesur <= '0';
		end if; 
		if(compt_time = 100000000) then 
			compt_time := 0;
		end if;
	end if;
end process;

-- process pour le calcul de la fréquence du vent 
process(in_freq_anemometre,reset_n,raz_n) 
begin 
	if(reset_n = '0' OR raz_n = '1') then 
		compt_freq <= 0;
	-- mesurer pendant la fenêtre de 1s
	elsif(start_mesur = '1' ) then 
		if(rising_edge(in_freq_anemometre)) then 
			compt_freq <= compt_freq +1;
		end if;
	elsif(start_mesur = '0') then 
		compt_freq <= 0;
	end if;
end process;

-- process pour sauvegarder la valeur de la mesure de la fréquence 
process(start_mesur) 
begin 
	if (falling_edge(start_mesur)) then 
		mesure_value <= compt_freq;-- sauvegarder une copie de la mesure 
	end if; 
end process;


-- process pour écrire dans les registres 
process(clk,reset_n,raz_n)
begin 
	if(reset_n = '0') then
		raz_n <= '0';
		continue <= '1'; -- mode continue mar défault
		start_stop <= '0';
	elsif(rising_edge(clk))then 
		if(chipselect = '1' and write_n = '0') then 
			if(address = '0') then 
				-- sélectionner le registre config
				raz_n <= writedata(0);
				continue <= writedata(1);
				start_stop <= writedata(2);
			end if;	
		end if;
	end if;
end process;

-- process pour lire des registres 
process(address,start_stop,continue,raz_n,data_anemometre,data_valid)
begin 
	if(chipselect = '1' and write_n = '1') then 
		-- lire la config 
		if(address = '0') then
			readdata <= X"0000000"&'0' & start_stop & continue & raz_n; -- compléter les 32 bits par des 0 , X pour héxa
		-- lire les données 
		elsif(address = '1') then 
			readdata <=    X"00000" & "000" & data_valid & data_anemometre;

		end if;
	end if;
end process;


-- process pour la mise à jour de la sortie 
process(reset_n,raz_n,start_mesur)
variable memo_freq : integer range 0 to 250 := 0;
begin 
	if(reset_n = '0' OR raz_n = '1') then 
		data_anemometre <= "00000000";
		data_valid <= '0';
		memo_freq := 0;
		
	-- mode continue 
	elsif(continue = '1') then 
		if(start_mesur = '0') then
			data_anemometre <= std_logic_vector(to_unsigned(mesure_value, data_anemometre'length)); -- mise à jour de la sortie
			data_valid <= '1';
		else 
			data_valid <= '0';
		end if;
		
	-- mode monocoup
	elsif(continue = '0') then  
		if(start_stop ='1') then 
			data_anemometre <= std_logic_vector(to_unsigned(mesure_value, data_anemometre'length));-- nouvelle meure 
			data_valid <= '1';
			memo_freq := mesure_value;-- mémoriser la fréquence du vent 
		else 
			data_anemometre <= std_logic_vector(to_unsigned(memo_freq, data_anemometre'length));-- ancienne valeur 
			data_valid <= '0';
		end if;
	end if;
		
end process;
end archAvanemometre;