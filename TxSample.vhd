library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TxSample is
  Port ( Txck : in  STD_LOGIC;
         Txen : out  STD_LOGIC;
         Tx0 : out  STD_LOGIC;
         Tx1 : out  STD_LOGIC;
         Tx2 : out  STD_LOGIC;
         Tx3 : out  STD_LOGIC;
         Rx0 : in  STD_LOGIC;
         Rx1 : in  STD_LOGIC;
         Rx2 : in  STD_LOGIC;
         Rx3 : in  STD_LOGIC;
         Rxdv : in  STD_LOGIC;
         Rxer: in STD_LOGIC;
         Phynrst : out  STD_LOGIC;
         Mainck: in STD_LOGIC;
         Button: in STD_LOGIC;
         Main_rst: in STD_LOGIC;
         Led0: out STD_LOGIC;
         Led1: out STD_LOGIC);
end TxSample;

architecture Behavioral of TxSample is

  signal phy_ok: std_logic;

  signal txrq: std_logic;
  signal s_txrq: std_logic;
  signal s1_txrq: std_logic;

  signal tx_run: std_logic;
  signal s1_tx_run: std_logic;
  signal s_tx_run: std_logic;

  signal s1_button: std_logic;
  signal s_button: std_logic;
  signal reset_counter: std_logic_vector (24 downto 0);
  signal state: std_logic_vector (7 downto 0);
  signal debounced_button: std_logic;
  signal prev_button: std_logic;
  signal stable_counter: std_logic_vector (24 downto 0);
  signal prev_debounced_button: std_logic;

  signal Main_nrst: std_logic;
begin

Main_nrst <= not Main_rst;
Led1 <= Main_nrst;

  resetwait: process(Mainck, Main_nrst)
  begin
    if (Main_nrst = '0') then
      reset_counter <= (others => '0');
    elsif (Mainck'event AND Mainck = '1') then
      reset_counter <= std_logic_vector(unsigned(reset_counter) + 1);
    end if;
  end process;

  resetphy: process(Mainck, Main_nrst)
  begin
    if (Main_nrst = '0') then
      Phynrst <= '0';
      phy_ok <= '0';
    elsif (Mainck'event AND Mainck = '1') then
      if (unsigned(reset_counter) = 100000) then
        Phynrst <= '1';
      end if;
      if (unsigned(reset_counter) = 110000) then
        phy_ok <= '1';
      end if;
    end if;
  end process;

  debouncer: process(Mainck, Main_nrst)
  begin
    if (Main_nrst = '0') then
      debounced_button <= '0';
      stable_counter <= (others => '0');
      prev_button <= '0';
    elsif (Mainck'event AND Mainck = '1') then
      if (s_button = prev_button) then
        -- stable for 80mS
        if (unsigned(stable_counter) = x"3fffff") then
          stable_counter <= (others => '0');
          debounced_button <= s_button;
        else
          stable_counter <= std_logic_vector(unsigned(stable_counter) + 1);
        end if;
      else
        stable_counter <= (others => '0');
      end if;
      prev_button <= s_button;
    end if;
  end process;

  trigger: process(Mainck, Main_nrst)
  begin
    if (Main_nrst = '0') then
      txrq <= '0';
      prev_debounced_button <= '0';
    elsif (Mainck'event and Mainck = '1') then
      if (phy_ok = '1' and debounced_button = '1' and prev_debounced_button = '0' and s_tx_run = '0') then
        txrq <= '1';
      elsif (s_tx_run = '1') then
        txrq <= '0';
      end if;
      prev_debounced_button <= debounced_button;
    end if;
  end process;

  sync_Mainck: process(Mainck, Main_nrst)
  begin
    if (Main_nrst = '0') then
      s_button <= '0';
      s_tx_run <= '0';
      s1_button <= '0';
      s1_tx_run <= '0';
    elsif (Mainck'event AND Mainck = '1') then
--      s1_txrq <= txrq;
--      s_txrq <= s1_txrq;
      s1_button <= Button;
      s_button <= s1_button;
      s1_tx_run <= tx_run;
      s_tx_run <= s1_tx_run;
    end if;
  end process;

  sync_Txck: process(Txck, Main_nrst)
  begin
    if (Main_nrst = '0') then
      s_txrq <= '0';
      s1_txrq <= '0';
    elsif (Txck'event and Txck = '1') then
      s1_txrq <= txrq;
      s_txrq <= s1_txrq;
    end if;
  end process;

  ethtransmitter: process(Txck, Main_nrst)
  begin

    if (Main_nrst = '0') then
      state <= (others => '0');
      tx_run <= '0' ;
      Led0 <= '0';
      Txen <= '0';
      Tx0 <= '0';
      Tx1 <= '0';
      Tx2 <= '0';
      Tx3 <= '0';
    elsif(Txck'event AND Txck = '0') then
      if(s_txrq = '1' and tx_run = '0') then
        tx_run <= '1';
        state <= (others => '0');
        Led0 <= '1';
      end if;

      if(tx_run = '1') then
        if(unsigned(state) < 15) then    --15
          Txen <= '1';

          Tx0 <= '1';
          Tx1 <= '0';
          Tx2 <= '1';
          Tx3 <= '0';
        elsif (unsigned(state) = 15 ) then --16
          Tx0 <= '1';
          Tx1 <= '0';
          Tx2 <= '1';
          Tx3 <= '1';
        elsif (unsigned(state) > 15 AND unsigned(state) < (15+13)) then --12
          Tx0 <= '1';
          Tx1 <= '1';
          Tx2 <= '1';
          Tx3 <= '1';
        elsif (unsigned(state) = (15+13)) then --7
          Tx0 <= '1';
          Tx1 <= '0';
          Tx2 <= '0';
          Tx3 <= '0';                     --12+129 orig --12+4 -- 5 is discarded by atl1e
        elsif (unsigned(state) > (15+12) AND unsigned(state) < (15 + 13 + 10)) then
          Tx0 <= '0';
          Tx1 <= '0';
          Tx2 <= '0';
          Tx3 <= '0';
        elsif (unsigned(state) < (15 + 13 + 10 + 10)) then -- IFS
          Txen <= '0';
        else
          Led0 <= '0';
          tx_run <= '0';
        end if;
        state <= std_logic_vector(unsigned(state) + 1);

      end if; -- tx_run
    end if; -- ck
  end process;

end Behavioral;
