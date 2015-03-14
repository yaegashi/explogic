-- CONFINIT: Read data from Configuration PROM.
-- See XAPP694: Reading User Data from Configuration PROMs.
-- vim: set sw=2 sts=2:

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.ALL;
use IEEE.std_logic_arith.ALL;

entity CONFINIT is
  generic (
    J: integer := 2;
    K: integer := 5;
    L: integer := 14;
    M: integer := 16383;
    S: std_logic_vector := X"efbeadde" -- 0xdeadbeef in little endian order
  );
  port (
    CLK, RESET: in std_logic;
    START: in std_logic;
    A: out std_logic_vector(L-1 downto 0);
    D: out std_logic_vector(2**K-1 downto 0);
    RDY: in std_logic;
    STB, FIN: out std_logic;
    CDIN: in std_logic;
    CINIT, CCLK: out std_logic
  );
end CONFINIT;


architecture RTL of CONFINIT is

  type GLOBAL_STATE is (GS0, GS1, GS2);
  signal GSTATE: GLOBAL_STATE;
  constant FULL: std_logic_vector(J+K-1 downto 0) := (others=>'1');
  constant FINA: std_logic_vector(L-1 downto 0) := CONV_STD_LOGIC_VECTOR(M, L);
  signal COUNTER: std_logic_vector(J+K+L-1 downto 0);
  signal SR: std_logic_vector(2**K-1 downto 0);
  signal FOUND: std_logic;

begin

  process (RESET, CLK)
  begin
    if RESET = '1' then
      GSTATE <= GS0;
    elsif CLK'event and CLK = '1' then
      case GSTATE is
        when GS0 =>
          if START = '1' then
            GSTATE <= GS1;
          end if;
        when GS1 =>
          if FOUND = '1' then
            GSTATE <= GS2;
          end if;
        when GS2 =>
          if COUNTER = FINA & FULL then
            GSTATE <= GS0;
          end if;
        when others =>
          GSTATE <= GS0;
      end case;
    end if;
  end process;

  process (RESET, CLK)
  begin
    if RESET = '1' then
      COUNTER <= (others=>'0');
      SR <= (others=>'0');
    elsif CLK'event and CLK = '1' then
      case GSTATE is
        when GS0 =>
          COUNTER <= (others=>'0');
        when GS1 =>
          if FOUND = '1' then
            COUNTER <= (others=>'0');
          else
            COUNTER <= COUNTER + 1;
          end if;
        when GS2 =>
          if COUNTER(J+K-1 downto 0) /= FULL or RDY = '1' then
            COUNTER <= COUNTER + 1;
          end if;
      end case;
      if COUNTER(J-1 downto 0) = 2**(J-1)-1 then
        SR(SR'left-1 downto 0) <= SR(SR'left downto 1);
	SR(SR'left) <= CDIN;
      end if;
    end if;
  end process;

  FOUND <= '1' when COUNTER(J-1 downto 0) = 2**J-1 and SR = S else '0';

  A <= COUNTER(J+K+L-1 downto J+K);
  D <= SR;
  STB <= '1' when COUNTER(J+K-1 downto 0) = FULL else '0';
  FIN <= '1' when GSTATE = GS0 else '0';
  CCLK <= not COUNTER(J-1);
  CINIT <= '1';

end RTL;
