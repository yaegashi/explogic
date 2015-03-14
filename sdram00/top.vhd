-- Top level entity.
-- vim: set sw=2 sts=2:

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.ALL;
use IEEE.std_logic_arith.ALL;

library UNISIM;
use UNISIM.vcomponents.ALL;

entity TOP is
  port (
    CLK: in std_logic;
    SD_A: out std_logic_vector(12 downto 0);
    SD_DQ: inout std_logic_vector(15 downto 0);
    SD_BA: out std_logic_vector(1 downto 0);
    SD_RAS, SD_CAS, SD_WE, SD_CK_N, SD_CK_P, SD_CKE, SD_CS: out std_logic;
    SD_LDM, SD_UDM: out std_logic;
    SD_LDQS, SD_UDQS: inout std_logic;
    VR, VG, VB, VH, VV: out std_logic;
    CINIT, CCLK: out std_logic;
    CDIN: in std_logic;
    AD_CONV, AMP_CS, DAC_CS, SF_CE0: out std_logic;
    LED: out std_logic_vector(7 downto 0)
  );
end TOP;

architecture RTL of TOP is

  component SDRAMC
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
  end component;

  component CRTC
    generic (H0: integer := 640;
             H1: integer := 656;
             H2: integer := 752;
             H3: integer := 800;
             V0: integer := 480;
             V1: integer := 490;
             V2: integer := 492;
             V3: integer := 521);
    port (CLK, RESET: in std_logic;
          HSYNC, VSYNC, BLANK: out std_logic;
          HADDR, VADDR, MADDR: out integer);
  end component;

  component RAM16XYD
    generic (Y: integer := 32);
    port (WE, WCLK: in std_logic;
          A, DPRA: in std_logic_vector(3 downto 0);
          D: in std_logic_vector(Y-1 downto 0);
          SPO, DPO: out std_logic_vector(Y-1 downto 0));
  end component;

  component CONFINIT
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
  end component;

  signal IN_A: std_logic_vector(24 downto 0);
  signal IN_DM: std_logic_vector(3 downto 0);
  signal IN_DI, IN_DO: std_logic_vector(31 downto 0);
  signal IN_STB, IN_RW, IN_DRDY, IN_CRDY: std_logic;
  signal IN_CLK, IN_CLK0, IN_CLK1, IN_VCLK: std_logic;
  signal CLK0, CLK1, VCLK, RESET: std_logic;
  signal IN_VH, IN_VV, IN_BLANK: std_logic;
  signal IN_HADDR, IN_VADDR, IN_MADDR: integer;
  signal V0_D: std_logic_vector(31 downto 0);
  signal V0_MA, G_VA: std_logic_vector(18 downto 0);
  signal G_SA: std_logic_vector(15 downto 0);
  signal G_DA: std_logic_vector(3 downto 0);
  signal CI0_A: std_logic_vector(15 downto 0);
  signal CI0_D: std_logic_vector(31 downto 0);
  signal CI0_START, CI0_RDY, CI0_STB, CI0_FIN: std_logic;

  type G_STATE_TYPE is (START, INIT, IDLE, FETCH);
  signal G_STATE: G_STATE_TYPE;

begin

  -- Reset pulse generation.
  -- This component is optimized away on synthesis.
  ROC0: ROC port map (O => RESET);

  -- Clock generation.
  IBUFG0: IBUFG port map (I => CLK, O => IN_CLK);
  BUFG0: BUFG port map (I => IN_CLK0, O => CLK0);
  BUFG1: BUFG port map (I => IN_CLK1, O => CLK1);
  BUFG2: BUFG port map (I => IN_VCLK, O => VCLK);
  DCM0: DCM_SP
  generic map (
    CLKDV_DIVIDE => 2.0,
    STARTUP_WAIT => true
  )
  port map (
    -- 50MHz OSC (IC17)
    CLKIN => IN_CLK,
    CLKFB => CLK0,
    -- 50MHz CLK0, CLK1
    CLK0 => IN_CLK0,
    CLK180 => IN_CLK1,
    -- 100MHz CLK0, CLK1
    -- CLK2X => IN_CLK0,
    -- CLK2X180 => IN_CLK1,
    -- 25MHz VCLK
    CLKDV => IN_VCLK
  );

  -- DDR SDRAM controller.
  SDRAMC0: SDRAMC
  port map (
    CLK0 => CLK0,
    CLK1 => CLK1,
    RESET => RESET,
    A => IN_A,
    DM => IN_DM,
    DI => IN_DI,
    DO => IN_DO,
    STB => IN_STB,
    RW => IN_RW,
    DRDY => IN_DRDY,
    CRDY => IN_CRDY,
    RAM_A => SD_A,
    RAM_D => SD_DQ,
    RAM_BA => SD_BA,
    RAM_RAS => SD_RAS,
    RAM_CAS => SD_CAS,
    RAM_WE => SD_WE,
    RAM_CS => SD_CS,
    RAM_CKE => SD_CKE,
    RAM_DM(0) => SD_LDM,
    RAM_DM(1) => SD_UDM,
    RAM_DQS(0) => SD_LDQS,
    RAM_DQS(1) => SD_UDQS,
    RAM_CK_N => SD_CK_N,
    RAM_CK_P => SD_CK_P
  );

  IN_DM <= (others=>'0');
  IN_DI <= CI0_D;
  IN_A <= "00000000" & CI0_A & "0" when G_STATE = INIT else
          "00000000" & G_SA & "0";
  IN_STB <= CI0_STB when G_STATE = INIT else
            '1' when G_STATE = FETCH else
            '0';
  IN_RW <= '0' when G_STATE = INIT else '1';

  -- CRT controller.
  CRTC0: CRTC
  port map (
    CLK => VCLK,
    RESET => RESET,
    HSYNC => IN_VH,
    VSYNC => IN_VV,
    BLANK => IN_BLANK,
    HADDR => IN_HADDR,
    VADDR => IN_VADDR,
    MADDR => IN_MADDR
  );

  V0_MA <= CONV_STD_LOGIC_VECTOR(IN_MADDR, V0_MA'length);

  process (VCLK)
  begin
    if VCLK'event and VCLK = '1' then
      VH <= IN_VH;
      VV <= IN_VV;
      if IN_BLANK = '1' then
        VR <= '0';
        VG <= '0';
        VB <= '0';
      else
        case V0_MA(2 downto 0) is
          when "000" =>
            VR <= V0_D(0);
            VG <= V0_D(1);
            VB <= V0_D(2);
          when "001" =>
            VR <= V0_D(4);
            VG <= V0_D(5);
            VB <= V0_D(6);
          when "010" =>
            VR <= V0_D(8);
            VG <= V0_D(9);
            VB <= V0_D(10);
          when "011" =>
            VR <= V0_D(12);
            VG <= V0_D(13);
            VB <= V0_D(14);
          when "100" =>
            VR <= V0_D(16);
            VG <= V0_D(17);
            VB <= V0_D(18);
          when "101" =>
            VR <= V0_D(20);
            VG <= V0_D(21);
            VB <= V0_D(22);
          when "110" =>
            VR <= V0_D(24);
            VG <= V0_D(25);
            VB <= V0_D(26);
          when "111" =>
            VR <= V0_D(28);
            VG <= V0_D(29);
            VB <= V0_D(30);
          when others =>
            VR <= '-';
            VG <= '-';
            VB <= '-';
        end case;
      end if;
    end if;
  end process;

  -- Dual port ram for video output buffer.
  DPRAM0: RAM16XYD
  port map (
    WCLK => CLK0,
    WE => IN_DRDY,
    A => G_DA,
    D => IN_DO,
    DPRA => V0_MA(6 downto 3),
    DPO => V0_D
  );

  -- Read initializing data for SDRAM from Configuration PROM (XCF04S).
  CI0: CONFINIT
  generic map (L => 16, M => 640*480/8)
  port map (
    CLK => CLK0,
    RESET => RESET,
    START => CI0_START,
    A => CI0_A,
    D => CI0_D,
    RDY => CI0_RDY,
    STB => CI0_STB,
    FIN => CI0_FIN,
    CDIN => CDIN,
    CINIT => CINIT,
    CCLK => CCLK
  );

  CI0_START <= '1' when IN_CRDY = '1' and G_STATE = START else '0';
  CI0_RDY <= IN_CRDY;

  -- Main state transition.
  process (CLK0, RESET)
  begin
    if RESET = '1' then
      G_STATE <= START;
      G_SA <= (others => '0');
      G_VA <= (others=>'0');
      G_DA <= (others=>'0');
    elsif CLK0'event and CLK0 = '1' then
      G_VA <= V0_MA;
      case G_STATE is
        when START =>
          if CI0_FIN = '0' and IN_CRDY = '1' then
            G_STATE <= INIT;
          end if;
        when INIT =>
          if CI0_FIN = '1' then
            G_STATE <= IDLE;
          end if;
        when IDLE =>
          if G_VA(6 downto 4) = "111" then
            G_STATE <= FETCH;
            if G_VA(18 downto 7) = 640*480/128-1 then
              G_SA <= (others=>'0');
            else
              G_SA <= (G_VA(18 downto 7) + 1) & "0000";
            end if;
          end if;
        when FETCH =>
          if IN_CRDY = '1' then
            G_SA <= G_SA + 1;
            if G_SA(3 downto 0) = 15 then
              G_STATE <= IDLE;
            end if;
          end if;
        when others =>
          G_STATE <= INIT;
      end case;
      if IN_CRDY = '1' then
        G_DA <= G_SA(3 downto 0);
      end if;
    end if;
  end process;

  -- These pins need to be tied to '0' or '1' to avoid SPI bus contention.
  AD_CONV <= '0';
  AMP_CS <= '1';
  DAC_CS <= '1';
  SF_CE0 <= '1';

  -- LEDs for debugging.
  LED <= (others=>'0');

end RTL;
