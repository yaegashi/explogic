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
    VR, VG, VB, VH, VV: out std_logic
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
      STR, RW: in std_logic;
      DRDY, CRDY: out std_logic;
      RAM_A: out std_logic_vector(12 downto 0);
      RAM_D: inout std_logic_vector(15 downto 0);
      RAM_BA: out std_logic_vector(1 downto 0);
      RAM_RAS, RAM_CAS, RAM_WE, RAM_CS, RAM_CKE: out std_logic;
      RAM_DM: out std_logic_vector(1 downto 0);
      RAM_DQS: inout std_logic_vector(1 downto 0)
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

  signal IN_A: std_logic_vector(24 downto 0);
  signal IN_DM: std_logic_vector(3 downto 0);
  signal IN_DI, IN_DO: std_logic_vector(31 downto 0);
  signal IN_STR, IN_RW, IN_DRDY, IN_CRDY: std_logic;
  signal IN_CLK, IN_CLK0, IN_CLK1, IN_VCLK: std_logic;
  signal CLK0, CLK1, VCLK, RESET: std_logic;
  signal IN_VH, IN_VV, IN_BLANK: std_logic;
  signal IN_HADDR, IN_VADDR, IN_MADDR: integer;
  signal IN_MA: std_logic_vector(17 downto 0);
  signal IN_VD: std_logic_vector(31 downto 0);
  signal IN_SDA: std_logic_vector(14 downto 0);
  signal IN_DPA: std_logic_vector(3 downto 0);

  type G_STATE_TYPE is (INIT, IDLE, FETCH);
  signal G_STATE: G_STATE_TYPE;

begin

  -- 
  ROC0: ROC port map (O => RESET);
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
    CLKIN => IN_CLK,
    CLKFB => CLK0,
    CLK2X => IN_CLK0,
    CLK2X180 => IN_CLK1,
    CLKDV => IN_VCLK
  );

  --
  SDRAMC0: SDRAMC
  port map (
    CLK0 => CLK0,
    CLK1 => CLK1,
    RESET => RESET,
    A => IN_A,
    DM => IN_DM,
    DI => IN_DI,
    DO => IN_DO,
    STR => IN_STR,
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
    RAM_DQS(1) => SD_UDQS
  );

  --
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

  IN_MA <= CONV_STD_LOGIC_VECTOR(IN_MADDR, IN_MA'length);

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
        case IN_MA(2 downto 0) is
          when "000" =>
            VR <= IN_VD(0);
            VG <= IN_VD(1);
            VB <= IN_VD(2);
          when "001" =>
            VR <= IN_VD(4);
            VG <= IN_VD(5);
            VB <= IN_VD(6);
          when "010" =>
            VR <= IN_VD(8);
            VG <= IN_VD(9);
            VB <= IN_VD(10);
          when "011" =>
            VR <= IN_VD(12);
            VG <= IN_VD(13);
            VB <= IN_VD(14);
          when "100" =>
            VR <= IN_VD(16);
            VG <= IN_VD(17);
            VB <= IN_VD(18);
          when "101" =>
            VR <= IN_VD(20);
            VG <= IN_VD(21);
            VB <= IN_VD(22);
          when "110" =>
            VR <= IN_VD(24);
            VG <= IN_VD(25);
            VB <= IN_VD(26);
          when "111" =>
            VR <= IN_VD(28);
            VG <= IN_VD(29);
            VB <= IN_VD(30);
          when others =>
            VR <= '0';
            VG <= '0';
            VB <= '0';
        end case;
      end if;
    end if;
  end process;

  --
  DPRAM0: RAM16XYD
  port map (
    WE => IN_DRDY,
    WCLK => CLK0,
    A => IN_DPA,
    DPRA => IN_MA(6 downto 3),
    D => IN_DO,
    SPO => open,
    DPO => IN_VD
  );

  --
  process (CLK0, RESET)
  begin
    if RESET = '1' then
      G_STATE <= INIT;
      IN_SDA <= (others => '0');
      IN_DPA <= (others => '0');
    elsif CLK0'event and CLK0 = '1' then
      case G_STATE is
        when INIT =>
          if IN_CRDY = '1' then
            IN_SDA <= IN_SDA + 1;
            if IN_SDA = 32767 then
              G_STATE <= IDLE;
            end if;
          end if;
        when IDLE =>
          if IN_MA(6 downto 0) = "1110000" then
            G_STATE <= FETCH;
            IN_SDA <= IN_MA(17 downto 3) + 2;
          end if;
        when FETCH =>
          if IN_CRDY = '1' then
            IN_DPA <= IN_SDA(3 downto 0);
            IN_SDA <= IN_SDA + 1;
            if IN_SDA(3 downto 0) = 15 then
              G_STATE <= IDLE;
            end if;
          end if;
        when others =>
          G_STATE <= INIT;
      end case;
    end if;
  end process;

  --
  IN_A <= "000000000" & IN_SDA & "0";
  IN_DM <= (others=>'0');
  IN_DI <= "01110110010101000011001000010000";
  IN_STR <= '1' when G_STATE = FETCH or G_STATE = INIT else '0';
  IN_RW <= '0' when G_STATE = INIT else '1';

  --
  SD_CK_P <= CLK0;
  SD_CK_N <= CLK1;

end RTL;
