-- DDR SDRAM MT46V32M16TG-6T
-- http://www.micron.com/~/media/documents/products/data-sheet/dram/ddr1/512mb_ddr.pdf
-- vim: set sw=2 sts=2:

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.ALL;

library UNISIM;
use UNISIM.vcomponents.ALL;

entity SDRAMC is
  generic (
    DEPTH: integer := 25;
    MRS0A: std_logic_vector(14 downto 0) := "010000000000000";
    MRS1A: std_logic_vector(14 downto 0) := "000000100100001";
    MRS2A: std_logic_vector(14 downto 0) := "000000000100001"
  );
  port (
    CLK0, CLK1, RESET: in std_logic;
    A: in std_logic_vector(DEPTH-1 downto 0);
    DM: in std_logic_vector(3 downto 0);
    DI: in std_logic_vector(31 downto 0);
    DO: out std_logic_vector(31 downto 0);
    STB, RW: in std_logic;
    DRDY, CRDY: out std_logic;
    RAM_A: out std_logic_vector(12 downto 0);
    RAM_D: inout std_logic_vector(15 downto 0);
    RAM_BA: out std_logic_vector(1 downto 0);
    RAM_RAS, RAM_CAS, RAM_WE, RAM_CS, RAM_CKE: out std_logic;
    RAM_DM: out std_logic_vector(1 downto 0);
    RAM_DQS: inout std_logic_vector(1 downto 0);
    RAM_CK_N, RAM_CK_P: out std_logic
  );
end SDRAMC;

architecture RTL of SDRAMC is

  signal IN_COUNTER: integer range 0 to 255;
  signal IN_REFRESH: integer range 0 to 1023; -- 10.24us @100MHz
  signal IN_A: std_logic_vector(DEPTH-1 downto 0);
  signal IN_D: std_logic_vector(31 downto 0);
  signal IN_DD: std_logic_vector(15 downto 0);
  signal IN_DM: std_logic_vector(3 downto 0);
  signal IN_DQS, IN_DDQS, IN_DDM: std_logic_vector(1 downto 0);
  signal IN_IE, IN_OE: std_logic;

  constant IDK: integer := 4;
  constant ODK: integer := 3;
  signal IDELAY: std_logic_vector(0 to IDK-1);
  signal ODELAY: std_logic_vector(0 to ODK-1);
  signal DELAYED_DQS, DELAYED_DQS_N: std_logic;
  signal DELAYED_CLK0, DELAYED_CLK1: std_logic;

  -- Prevent optimization for delay elements
  attribute KEEP: string;
  attribute KEEP of IDELAY: signal is "true";
  attribute KEEP of ODELAY: signal is "true";

  type STATE is (INIT, IDLE, REF, READ, WRITE);
  signal IN_STATE: STATE;

  type CMD_TYPE is (NOP, PALL, MRS0, MRS1, MRS2, REF, ACT, READ, WRITE);
  signal IN_CMD: CMD_TYPE;

begin

  process (RESET, CLK0)
  begin
    if RESET = '1' then
      IN_STATE <= INIT;
      IN_COUNTER <= 0;
      IN_REFRESH <= 0;
      IN_A <= (others=>'0');
    elsif CLK0'event and CLK0 = '1' then
      --
      case IN_STATE is
        when IDLE =>
          if STB = '1' then
            if RW = '1' then
              IN_STATE <= READ;
              IN_A <= A;
            else
              IN_STATE <= WRITE;
              IN_A <= A;
              IN_D <= DI;
              IN_DM <= DM;
            end if;
          elsif IN_REFRESH >= 512 then
            IN_STATE <= REF;
          end if;
        when INIT =>
          if IN_COUNTER = 255 then
            IN_STATE <= IDLE;
          end if;
        when REF =>
          if IN_COUNTER = 8 then
            IN_STATE <= IDLE;
          end if;
        when READ =>
          if IN_COUNTER = 5 then
            IN_STATE <= IDLE;
          end if;
        when WRITE =>
          if IN_COUNTER = 6 then
            IN_STATE <= IDLE;
          end if;
        when others =>
          IN_STATE <= INIT;
      end case;
      --
      if IN_STATE = IDLE then
        IN_COUNTER <= 0;
      else
        IN_COUNTER <= IN_COUNTER + 1;
      end if;
      -- refresh period 64ms, count 8192, rate 7.8125us
      if IN_STATE = REF then
        IN_REFRESH <= 0;
      else
        IN_REFRESH <= IN_REFRESH + 1;
      end if;
    end if;
  end process;

  process (IN_STATE, IN_COUNTER)
  begin
    if IN_STATE = INIT then
      if IN_COUNTER = 0 then
        IN_CMD <= NOP;
      elsif IN_COUNTER = 12 then
        IN_CMD <= PALL; -- wait tRP  15ns
      elsif IN_COUNTER = 14 then
        IN_CMD <= MRS0; -- wait tMRD 12ns
      elsif IN_COUNTER = 16 then
        IN_CMD <= MRS1; -- wait tMRD 12ns
      elsif IN_COUNTER = 18 then
        IN_CMD <= PALL; -- wait tRP  15ns
      elsif IN_COUNTER = 20 then
        IN_CMD <= REF;  -- wait tRFC 72ns
      elsif IN_COUNTER = 30 then
        IN_CMD <= REF;  -- wait tRFC 72ns
      elsif IN_COUNTER = 40 then
        IN_CMD <= MRS2; -- wait tMRD 12ns
      else
        IN_CMD <= NOP;
      end if;
    elsif IN_STATE = REF then
      if IN_COUNTER = 0 then
        IN_CMD <= REF;  -- wait tRFC 72ns
      else
        IN_CMD <= NOP;
      end if;
    elsif IN_STATE = READ then
      if IN_COUNTER = 0 then
        IN_CMD <= ACT;  -- wait tRAP 15ns
      elsif IN_COUNTER = 2 then
        IN_CMD <= READ;
      else
        IN_CMD <= NOP;
      end if;
    elsif IN_STATE = WRITE then
      if IN_COUNTER = 0 then
        IN_CMD <= ACT;  -- wait tRCD 15ns
      elsif IN_COUNTER = 2 then
        IN_CMD <= WRITE;
      else
        IN_CMD <= NOP;
      end if;
    else
      IN_CMD <= NOP;
    end if;
  end process;

  process (IN_CMD, IN_A)
  begin
    if IN_CMD = PALL then
      RAM_A <= (others=>'1');
      RAM_BA <= (others=>'1');
      RAM_CS <= '0';
      RAM_RAS <= '0';
      RAM_CAS <= '1';
      RAM_WE <= '0';
    elsif IN_CMD = MRS0 then
      RAM_A <= MRS0A(12 downto 0);
      RAM_BA <= MRS0A(14 downto 13);
      RAM_CS <= '0';
      RAM_RAS <= '0';
      RAM_CAS <= '0';
      RAM_WE <= '0';
    elsif IN_CMD = MRS1 then
      RAM_A <= MRS1A(12 downto 0);
      RAM_BA <= MRS1A(14 downto 13);
      RAM_CS <= '0';
      RAM_RAS <= '0';
      RAM_CAS <= '0';
      RAM_WE <= '0';
    elsif IN_CMD = MRS2 then
      RAM_A <= MRS2A(12 downto 0);
      RAM_BA <= MRS2A(14 downto 13);
      RAM_CS <= '0';
      RAM_RAS <= '0';
      RAM_CAS <= '0';
      RAM_WE <= '0';
    elsif IN_CMD = REF then
      RAM_A <= (others=>'0');
      RAM_BA <= (others=>'0');
      RAM_CS <= '0';
      RAM_RAS <= '0';
      RAM_CAS <= '0';
      RAM_WE <= '1';
    elsif IN_CMD = ACT then
      RAM_A <= IN_A(DEPTH-3 downto 10);
      RAM_BA <= IN_A(DEPTH-1 downto DEPTH-2);
      RAM_CS <= '0';
      RAM_RAS <= '0';
      RAM_CAS <= '1';
      RAM_WE <= '1';
    elsif IN_CMD = READ then
      RAM_A(12 downto 10) <= (others=>'1'); -- auto precharge
      RAM_A(9 downto 0) <= IN_A(9 downto 0);
      RAM_BA <= IN_A(DEPTH-1 downto DEPTH-2);
      RAM_CS <= '0';
      RAM_RAS <= '1';
      RAM_CAS <= '0';
      RAM_WE <= '1';
    elsif IN_CMD = WRITE then
      RAM_A(12 downto 10) <= (others=>'1'); -- auto precharge
      RAM_A(9 downto 0) <= IN_A(9 downto 0);
      RAM_BA <= IN_A(DEPTH-1 downto DEPTH-2);
      RAM_CS <= '0';
      RAM_RAS <= '1';
      RAM_CAS <= '0';
      RAM_WE <= '0';
    else
      RAM_A <= (others=>'1');
      RAM_BA <= (others=>'1');
      RAM_CS <= '0';
      RAM_RAS <= '1';
      RAM_CAS <= '1';
      RAM_WE <= '1';
    end if;
  end process;

  DM_DQS:
  for i in 0 to 1 generate
  begin
    DM: ODDR2
    port map (
      Q => IN_DDM(i),
      C0 => CLK0,
      C1 => CLK1,
      CE => '1',
      D0 => IN_DM(i),
      D1 => IN_DM(i+2),
      R => '0',
      S => '0'
    );
    DQS: ODDR2
    port map (
      Q => IN_DDQS(i),
      C0 => DELAYED_CLK0,
      C1 => DELAYED_CLK1,
      CE => '1',
      D0 => IN_DQS(0),
      D1 => IN_DQS(1),
      R => '0',
      S => '0'
    );
  end generate;

  DI_DO:
  for i in 0 to 15 generate
  begin
    DI: IDDR2
    port map (
      Q0 => DO(i),
      Q1 => DO(i+16),
      C0 => DELAYED_DQS,
      C1 => DELAYED_DQS_N,
      CE => IN_IE,
      D => RAM_D(i),
      R => '0',
      S => '0'
    );
    DO: ODDR2
    port map (
      Q => IN_DD(i),
      C0 => CLK0,
      C1 => CLK1,
      CE => '1',
      D0 => IN_D(i),
      D1 => IN_D(i+16),
      R => '0',
      S => '0'
    );
  end generate;

  process (CLK0, RESET)
  begin
    if RESET = '1' then
      IN_IE <= '0';
      IN_OE <= '0';
    elsif CLK0'event and CLK0 = '1' then
      if IN_STATE = READ and IN_COUNTER = 4 then
        IN_IE <= '1';
      else
        IN_IE <= '0';
      end if;
      if IN_STATE = WRITE and IN_COUNTER >= 2 and IN_COUNTER <= 3 then
        IN_OE <= '1';
      else
        IN_OE <= '0';
      end if;
      if IN_STATE = WRITE and IN_COUNTER = 2 then
        IN_DQS <= "01";
      else
        IN_DQS <= "00";
      end if;
    end if;
  end process;

  RAM_CKE <= '0' when IN_STATE = INIT and IN_COUNTER < 10 else '1';
  RAM_D <= IN_DD when IN_OE = '1' else (others=>'Z');
  RAM_DQS <= IN_DDQS when IN_OE = '1' else (others=>'Z');
  RAM_DM <= IN_DDM;

  CRDY <= '1' when IN_STATE = IDLE else '0';

  process (CLK0, RESET)
  begin
    if RESET = '1' then
      DRDY <= '0';
    elsif CLK0'event and CLK0 = '1' then
      if IN_STATE = READ and IN_COUNTER = 5 then
        DRDY <= '1';
      else
        DRDY <= '0';
      end if;
    end if;
  end process;

  -- DDR clock forwarding
  FWD_CK_P: ODDR2
  port map (
    Q => RAM_CK_P, C0 => CLK0, C1 => CLK1, CE => '1',
    D0 => '1', D1 => '0', R => '0', S => '0'
  );
  FWD_CK_N: ODDR2
  port map (
    Q => RAM_CK_N, C0 => CLK0, C1 => CLK1, CE => '1',
    D0 => '0', D1 => '1', R => '0', S => '0'
  );

  -- CLK delay for DQS output.
  ODELAY0:
  for i in 0 to ODK-2 generate
  begin
    LUT0: LUT2
    generic map (INIT => "1100")
    port map (
      I0 => ODELAY(0),
      I1 => ODELAY(i),
      O => ODELAY(i+1)
    );
  end generate;
  ODELAY(0) <= CLK0;
  DELAYED_CLK0 <= ODELAY(ODK-1);
  DELAYED_CLK1 <= not ODELAY(ODK-1);

  -- DQS delay for input FFs.
  IDELAY0:
  for i in 0 to IDK-2 generate
  begin
    LUT0: LUT2
    generic map (INIT => "1100")
    port map (
      I0 => IDELAY(0),
      I1 => IDELAY(i),
      O => IDELAY(i+1)
    );
  end generate;
  IDELAY(0) <= not RAM_DQS(0);
  DELAYED_DQS <= not IDELAY(IDK-1);
  DELAYED_DQS_N <= IDELAY(IDK-1);

end RTL;
