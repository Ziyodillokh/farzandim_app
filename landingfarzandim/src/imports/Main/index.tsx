import svgPaths from "./svg-35b9599amp";
import imgIMockupIPhone14 from "./607c6e3bfba22c047f8329be69ecf4a5a5d7fe7f.png";
import imgIMockupIPhone15 from "./30db65037230d0629c4691f397e6e6f40d4fb22f.png";
import imgIMockupIPhone16 from "./32807ace4ae9df2d648b46613faa438f8127f82b.png";
import { imgVector, imgGroup, imgGroup1, imgGroup2, imgGroup3, imgGroup4, imgGroup5, imgGroup6 } from "./svg-g06a3";

function LogoIcon() {
  return (
    <div className="relative shrink-0 size-[32px]" data-name="Logo Icon">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 32 32">
        <g id="Logo Icon">
          <rect fill="var(--fill-0, white)" height="32" rx="8" width="32" />
          <path clipRule="evenodd" d={svgPaths.p2a8c3b90} fill="var(--fill-0, black)" fillRule="evenodd" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function LogoWrap() {
  return (
    <div className="h-[32px] relative shrink-0 w-[142px]" data-name="Logo wrap">
      <div className="-translate-x-1/2 -translate-y-1/2 absolute content-stretch flex items-start left-[calc(50%-55px)] top-1/2" data-name="Logomark">
        <LogoIcon />
      </div>
      <p className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] absolute font-['Inter:Semi_Bold',sans-serif] font-semibold leading-[36.506px] left-[39px] not-italic text-[28px] text-white top-[calc(50%-11.5px)] tracking-[-0.28px] whitespace-nowrap">Parvoz</p>
    </div>
  );
}

function Frame() {
  return (
    <div className="[word-break:break-word] content-stretch flex flex-col gap-[20px] items-center not-italic relative shrink-0 text-center w-full">
      <p className="font-['Inter:semibold',sans-serif] leading-[48px] min-w-full relative shrink-0 text-[40px] text-white tracking-[-0.4px] w-[min-content]">Bolalar uchun xavfsiz va foydali kontent platformasi</p>
      <p className="font-['Inter:medium',sans-serif] leading-[26px] relative shrink-0 text-[18px] text-[rgba(255,255,255,0.8)] tracking-[-0.04px] whitespace-nowrap">Videolar, audiokitoblar va bilim konkurslari - barchasi nazorat ostida</p>
    </div>
  );
}

function Frame1() {
  return (
    <div className="absolute content-stretch flex flex-col gap-[90px] items-center left-[calc(16.67%+117px)] top-[32px] w-[727px]">
      <div className="content-stretch flex items-center relative shrink-0 w-[188px]" data-name="Logo">
        <LogoWrap />
      </div>
      <Frame />
    </div>
  );
}

function Group1() {
  return (
    <div className="absolute contents left-[calc(25%+101px)] top-[364px]">
      <div className="absolute h-[341px] left-[calc(33.33%+60px)] top-[400px] w-[360px]">
        <div className="absolute inset-[-61.58%_-58.33%]">
          <svg className="block size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 780 761">
            <g filter="url(#filter0_f_1_592)" id="Ellipse 2">
              <ellipse cx="390" cy="380.5" fill="url(#paint0_linear_1_592)" fillOpacity="0.6" rx="180" ry="170.5" />
            </g>
            <defs>
              <filter colorInterpolationFilters="sRGB" filterUnits="userSpaceOnUse" height="761" id="filter0_f_1_592" width="780" x="0" y="0">
                <feFlood floodOpacity="0" result="BackgroundImageFix" />
                <feBlend in="SourceGraphic" in2="BackgroundImageFix" mode="normal" result="shape" />
                <feGaussianBlur result="effect1_foregroundBlur_1_592" stdDeviation="105" />
              </filter>
              <linearGradient gradientUnits="userSpaceOnUse" id="paint0_linear_1_592" x1="390" x2="390" y1="210" y2="551">
                <stop stopColor="#8A62F9" />
                <stop offset="0.603244" stopColor="#424357" />
              </linearGradient>
            </defs>
          </svg>
        </div>
      </div>
      <div className="absolute flex h-[397.949px] items-center justify-center left-[calc(50%+25.62px)] top-[380.23px] w-[234.538px]">
        <div className="flex-none rotate-8">
          <div className="h-[376px] relative w-[184px]" data-name="iMockup - iPhone 14">
            <img alt="" className="absolute inset-0 max-w-none object-cover pointer-events-none size-full" src={imgIMockupIPhone14} />
          </div>
        </div>
      </div>
      <div className="absolute flex h-[397.949px] items-center justify-center left-[calc(25%+101px)] top-[380px] w-[234.538px]">
        <div className="-rotate-8 flex-none">
          <div className="h-[376px] relative w-[184px]" data-name="iMockup - iPhone 15">
            <div aria-hidden className="absolute inset-0 pointer-events-none">
              <img alt="" className="absolute max-w-none object-cover size-full" src={imgIMockupIPhone14} />
              <img alt="" className="absolute max-w-none object-cover size-full" src={imgIMockupIPhone15} />
            </div>
          </div>
        </div>
      </div>
      <div className="-translate-x-1/2 absolute h-[387px] left-[calc(50%+0.5px)] top-[364px] w-[189px]" data-name="iMockup - iPhone 14">
        <img alt="" className="absolute inset-0 max-w-none object-cover pointer-events-none size-full" src={imgIMockupIPhone16} />
      </div>
    </div>
  );
}

function Heading() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0 w-full" data-name="Heading 2">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Semi_Bold',sans-serif] font-semibold justify-center leading-[0] not-italic relative shrink-0 text-[18px] text-white tracking-[-0.04px] whitespace-nowrap">
        <p className="leading-[24px] mb-0">Mobil ilovamizni</p>
        <p className="leading-[24px]">yuklab oling</p>
      </div>
    </div>
  );
}

function Container3() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0 w-full" data-name="Container">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Regular',sans-serif] font-normal justify-center leading-[0] not-italic relative shrink-0 text-[12px] text-white whitespace-nowrap">
        <p className="leading-[16px] mb-0">Ushbu funksiyadan va ko‘proq</p>
        <p className="leading-[16px]">imkoniyatlardan foydalaning!</p>
      </div>
    </div>
  );
}

function Container2() {
  return (
    <div className="content-stretch flex flex-col items-start justify-between min-w-[197px] relative self-stretch shrink-0 w-[197px]" data-name="Container">
      <Heading />
      <Container3 />
    </div>
  );
}

function Group2() {
  return (
    <div className="absolute inset-0 mask-position-[0px_0px,_1.727px_1.729px]" style={{ maskImage: `url("${imgVector}"), url("${imgGroup}")` }} data-name="Group">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 72 72">
        <g id="Group">
          <path d="M72 0H0V72H72V0Z" fill="var(--fill-0, #0F0F10)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function MaskGroup() {
  return (
    <div className="absolute contents inset-[2.4%_2.6%_2.6%_2.4%]" data-name="Mask group">
      <Group2 />
    </div>
  );
}

function Group3() {
  return (
    <div className="absolute inset-[2.4%_71%_71%_2.4%] mask-position-[-1.727px_-1.729px,_0px_0px]" style={{ maskImage: `url("${imgVector}"), url("${imgGroup1}")` }} data-name="Group">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 19.152 19.152">
        <g id="Group">
          <path d="M19.152 0H0V19.152H19.152V0Z" fill="var(--fill-0, #0F0F10)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function MaskGroup1() {
  return (
    <div className="absolute contents inset-[2.4%_71%_71%_2.4%]" data-name="Mask group">
      <Group3 />
    </div>
  );
}

function Group4() {
  return (
    <div className="absolute inset-[10%_78.6%_78.6%_10%] mask-position-[-7.199px_-7.199px,_0px_0px]" style={{ maskImage: `url("${imgVector}"), url("${imgGroup2}")` }} data-name="Group">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 8.208 8.208">
        <g id="Group">
          <path d="M8.208 0H0V8.208H8.208V0Z" fill="var(--fill-0, #0F0F10)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function MaskGroup2() {
  return (
    <div className="absolute contents inset-[10%_78.6%_78.6%_10%]" data-name="Mask group">
      <Group4 />
    </div>
  );
}

function Group5() {
  return (
    <div className="absolute inset-[2.4%_2.6%_71%_70.8%] mask-position-[-50.977px_-1.729px,_0px_0px]" style={{ maskImage: `url("${imgVector}"), url("${imgGroup3}")` }} data-name="Group">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 19.152 19.152">
        <g id="Group">
          <path d="M19.152 0H0V19.152H19.152V0Z" fill="var(--fill-0, #0F0F10)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function MaskGroup3() {
  return (
    <div className="absolute contents inset-[2.4%_2.6%_71%_70.8%]" data-name="Mask group">
      <Group5 />
    </div>
  );
}

function Group6() {
  return (
    <div className="absolute inset-[10%_10.2%_78.6%_78.4%] mask-position-[-56.449px_-7.199px,_0px_0px]" style={{ maskImage: `url("${imgVector}"), url("${imgGroup4}")` }} data-name="Group">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 8.208 8.208">
        <g id="Group">
          <path d="M8.208 0H0V8.208H8.208V0Z" fill="var(--fill-0, #0F0F10)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function MaskGroup4() {
  return (
    <div className="absolute contents inset-[10%_10.2%_78.6%_78.4%]" data-name="Mask group">
      <Group6 />
    </div>
  );
}

function Group7() {
  return (
    <div className="absolute inset-[70.8%_71%_2.6%_2.4%] mask-position-[-1.727px_-50.977px,_0px_0px]" style={{ maskImage: `url("${imgVector}"), url("${imgGroup5}")` }} data-name="Group">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 19.152 19.152">
        <g id="Group">
          <path d="M19.152 0H0V19.152H19.152V0Z" fill="var(--fill-0, #0F0F10)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function MaskGroup5() {
  return (
    <div className="absolute contents inset-[70.8%_71%_2.6%_2.4%]" data-name="Mask group">
      <Group7 />
    </div>
  );
}

function Group8() {
  return (
    <div className="absolute inset-[78.4%_78.6%_10.2%_10%] mask-position-[-7.199px_-56.447px,_0px_0px]" style={{ maskImage: `url("${imgVector}"), url("${imgGroup6}")` }} data-name="Group">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 8.208 8.208">
        <g id="Group">
          <path d="M8.208 0H0V8.208H8.208V0Z" fill="var(--fill-0, #0F0F10)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function MaskGroup6() {
  return (
    <div className="absolute contents inset-[78.4%_78.6%_10.2%_10%]" data-name="Mask group">
      <Group8 />
    </div>
  );
}

function Group() {
  return (
    <div className="absolute contents inset-0" data-name="Group">
      <div className="absolute inset-0 mask-alpha mask-intersect mask-no-clip mask-no-repeat mask-size-[72px_72px]" style={{ maskImage: `url("${imgVector}")` }} data-name="Vector">
        <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 72 72">
          <path d="M72 0H0V72H72V0Z" fill="var(--fill-0, white)" id="Vector" />
        </svg>
      </div>
      <MaskGroup />
      <MaskGroup1 />
      <MaskGroup2 />
      <MaskGroup3 />
      <MaskGroup4 />
      <MaskGroup5 />
      <MaskGroup6 />
    </div>
  );
}

function ClipPathGroup() {
  return (
    <div className="absolute contents inset-0" data-name="Clip path group">
      <Group />
    </div>
  );
}

function Svg() {
  return (
    <div className="overflow-clip relative shrink-0 size-[72px]" data-name="SVG">
      <ClipPathGroup />
    </div>
  );
}

function Container4() {
  return (
    <div className="content-stretch flex flex-[1_0_0] h-full items-center justify-center min-w-px relative rounded-[8px]" data-name="Container">
      <Svg />
    </div>
  );
}

function Background() {
  return (
    <div className="bg-white content-stretch flex items-center justify-center relative rounded-[8px] shrink-0 size-[86px]" data-name="Background">
      <Container4 />
    </div>
  );
}

function Container1() {
  return (
    <div className="content-stretch flex items-start justify-between relative shrink-0 w-full" data-name="Container">
      <Container2 />
      <Background />
    </div>
  );
}

function Svg1() {
  return (
    <div className="h-[16px] relative shrink-0 w-[65px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 65 16">
        <g clipPath="url(#clip0_1_623)" id="SVG">
          <path d={svgPaths.p1326af00} fill="var(--fill-0, black)" id="Vector" />
          <path d={svgPaths.p235cb510} fill="var(--fill-0, black)" id="Vector_2" />
          <path d={svgPaths.p19e90c00} fill="var(--fill-0, black)" id="Vector_3" />
          <path d={svgPaths.p253dc400} fill="var(--fill-0, black)" id="Vector_4" />
          <path d={svgPaths.p15441180} fill="var(--fill-0, black)" id="Vector_5" />
          <path d={svgPaths.p1a5d8400} fill="var(--fill-0, black)" id="Vector_6" />
          <path d={svgPaths.p30084e80} fill="var(--fill-0, black)" id="Vector_7" />
          <path d={svgPaths.p200b7a80} fill="var(--fill-0, black)" id="Vector_8" />
          <path d={svgPaths.p15b74e00} fill="var(--fill-0, black)" id="Vector_9" />
          <path d={svgPaths.p2745e600} fill="var(--fill-0, black)" id="Vector_10" />
          <path d={svgPaths.p25c30b40} fill="var(--fill-0, black)" id="Vector_11" />
          <path d={svgPaths.p1a0fa880} fill="var(--fill-0, black)" id="Vector_12" />
          <path d={svgPaths.p37e51d00} fill="var(--fill-0, black)" id="Vector_13" />
          <path d={svgPaths.p6650500} fill="var(--fill-0, black)" id="Vector_14" />
          <path d={svgPaths.p127ab700} fill="var(--fill-0, black)" id="Vector_15" />
          <path d={svgPaths.p2f232380} fill="var(--fill-0, black)" id="Vector_16" />
          <path d={svgPaths.p2a630940} fill="var(--fill-0, black)" id="Vector_17" />
          <path d={svgPaths.p27c43c00} fill="var(--fill-0, black)" id="Vector_18" />
          <path d={svgPaths.p14ef5a00} fill="var(--fill-0, black)" id="Vector_19" />
          <path d={svgPaths.p3a0f5a00} fill="var(--fill-0, black)" id="Vector_20" />
          <path d={svgPaths.p33c50500} fill="var(--fill-0, black)" id="Vector_21" />
          <path d={svgPaths.p9bd500} fill="var(--fill-0, black)" id="Vector_22" />
          <path d={svgPaths.p1f19aef2} fill="var(--fill-0, black)" id="Vector_23" />
        </g>
        <defs>
          <clipPath id="clip0_1_623">
            <rect fill="white" height="16" width="65" />
          </clipPath>
        </defs>
      </svg>
    </div>
  );
}

function Overlay() {
  return (
    <div className="bg-[#c6ff7f] relative rounded-[4px] shrink-0 w-full" data-name="Overlay">
      <div className="content-stretch flex flex-col items-start px-[10px] py-[6px] relative size-full">
        <Svg1 />
      </div>
    </div>
  );
}

function Link() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0 w-[85px]" data-name="Link">
      <Overlay />
    </div>
  );
}

function Svg2() {
  return (
    <div className="h-[16px] relative shrink-0 w-[67px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 67 16">
        <g clipPath="url(#clip0_1_659)" id="SVG">
          <path d={svgPaths.p3048e400} fill="var(--fill-0, black)" id="Vector" />
          <path clipRule="evenodd" d={svgPaths.pfb63300} fill="var(--fill-0, black)" fillRule="evenodd" id="Vector_2" />
          <path clipRule="evenodd" d={svgPaths.p10107d00} fill="url(#paint0_linear_1_659)" fillRule="evenodd" id="Vector_3" />
          <path clipRule="evenodd" d={svgPaths.p36b2980} fill="url(#paint1_linear_1_659)" fillRule="evenodd" id="Vector_4" />
          <path clipRule="evenodd" d={svgPaths.p25df0800} fill="url(#paint2_linear_1_659)" fillRule="evenodd" id="Vector_5" />
          <path clipRule="evenodd" d={svgPaths.p18b05d00} fill="url(#paint3_linear_1_659)" fillRule="evenodd" id="Vector_6" />
          <path clipRule="evenodd" d={svgPaths.p5232b00} fill="var(--fill-0, black)" fillRule="evenodd" id="Vector_7" opacity="0.2" />
          <path clipRule="evenodd" d={svgPaths.p28c54e00} fill="var(--fill-0, black)" fillRule="evenodd" id="Vector_8" opacity="0.12" />
          <path clipRule="evenodd" d={svgPaths.p296c4780} fill="var(--fill-0, white)" fillRule="evenodd" id="Vector_9" opacity="0.25" />
        </g>
        <defs>
          <linearGradient gradientUnits="userSpaceOnUse" id="paint0_linear_1_659" x1="6.80386" x2="-4.64482" y1="1.13735" y2="4.13322">
            <stop stopColor="#00BEFF" />
            <stop offset="0.00657" stopColor="#00BEFF" />
            <stop offset="0.2601" stopColor="#00BEFF" />
            <stop offset="0.5122" stopColor="#00E3FF" />
            <stop offset="0.7604" stopColor="#00E3FF" />
            <stop offset="1" stopColor="#00E3FF" />
          </linearGradient>
          <linearGradient gradientUnits="userSpaceOnUse" id="paint1_linear_1_659" x1="13.7307" x2="-0.195703" y1="7.75587" y2="7.75587">
            <stop stopColor="#FFE000" />
            <stop offset="0.4087" stopColor="#FF9C00" />
            <stop offset="0.7754" stopColor="#FF9C00" />
            <stop offset="1" stopColor="#FF9C00" />
          </linearGradient>
          <linearGradient gradientUnits="userSpaceOnUse" id="paint2_linear_1_659" x1="8.54607" x2="-0.870355" y1="9.1022" y2="24.6669">
            <stop stopColor="#FF3A44" />
            <stop offset="1" stopColor="#C31162" />
          </linearGradient>
          <linearGradient gradientUnits="userSpaceOnUse" id="paint3_linear_1_659" x1="-1.54421" x2="2.65689" y1="-3.86032" y2="3.09122">
            <stop stopColor="#32A071" />
            <stop offset="0.0685" stopColor="#2DA771" />
            <stop offset="0.4762" stopColor="#15CF74" />
            <stop offset="0.8009" stopColor="#06E775" />
            <stop offset="1" stopColor="#00F076" />
          </linearGradient>
          <clipPath id="clip0_1_659">
            <rect fill="white" height="16" width="67" />
          </clipPath>
        </defs>
      </svg>
    </div>
  );
}

function Overlay1() {
  return (
    <div className="bg-[#c6ff7f] relative rounded-[4px] shrink-0 w-full" data-name="Overlay">
      <div className="content-stretch flex flex-col items-start px-[10px] py-[6px] relative size-full">
        <Svg2 />
      </div>
    </div>
  );
}

function Link1() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0 w-[87px]" data-name="Link">
      <Overlay1 />
    </div>
  );
}

function Svg3() {
  return (
    <div className="h-[16px] relative shrink-0 w-[70px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 70 16">
        <g clipPath="url(#clip0_1_594)" id="SVG">
          <path d={svgPaths.p26b09c80} fill="var(--fill-0, black)" id="Vector" />
          <path d={svgPaths.p599b330} fill="var(--fill-0, black)" id="Vector_2" />
          <path d={svgPaths.p4f21d00} fill="var(--fill-0, black)" id="Vector_3" />
          <path d={svgPaths.p14fbe6f0} fill="var(--fill-0, black)" id="Vector_4" />
          <path d={svgPaths.p3fdacc00} fill="var(--fill-0, black)" id="Vector_5" />
          <path d={svgPaths.p1aa2bac0} fill="var(--fill-0, black)" id="Vector_6" />
          <path d={svgPaths.p248bfe80} fill="var(--fill-0, black)" id="Vector_7" />
          <path d={svgPaths.p2d5c9800} fill="var(--fill-0, black)" id="Vector_8" />
          <path d={svgPaths.p39fbe00} fill="var(--fill-0, black)" id="Vector_9" />
          <path d={svgPaths.p4f94af0} fill="var(--fill-0, black)" id="Vector_10" />
          <path d={svgPaths.p27e68700} fill="var(--fill-0, black)" id="Vector_11" />
          <path d={svgPaths.p3a416d00} fill="var(--fill-0, black)" id="Vector_12" />
          <path d={svgPaths.p126cda00} fill="var(--fill-0, black)" id="Vector_13" />
          <path d={svgPaths.pe0667f0} fill="var(--fill-0, black)" id="Vector_14" />
          <path d={svgPaths.p2980e300} fill="var(--fill-0, black)" id="Vector_15" />
          <path d={svgPaths.pe178d80} fill="var(--fill-0, black)" id="Vector_16" />
          <path d={svgPaths.p38b9a000} fill="var(--fill-0, black)" id="Vector_17" />
          <path d={svgPaths.p33c7c00} fill="var(--fill-0, black)" id="Vector_18" />
          <path d={svgPaths.p5f93000} fill="var(--fill-0, black)" id="Vector_19" />
          <path d={svgPaths.p31d4e700} fill="var(--fill-0, black)" id="Vector_20" />
          <path d={svgPaths.p21e65900} fill="var(--fill-0, black)" id="Vector_21" />
          <path clipRule="evenodd" d={svgPaths.p277c1500} fill="var(--fill-0, #C8102E)" fillRule="evenodd" id="Vector_22" />
          <path d={svgPaths.p7ef7c00} fill="var(--fill-0, white)" id="Vector_23" />
          <path d={svgPaths.p1bf7c80} fill="var(--fill-0, white)" id="Vector_24" />
        </g>
        <defs>
          <clipPath id="clip0_1_594">
            <rect fill="white" height="16" width="70" />
          </clipPath>
        </defs>
      </svg>
    </div>
  );
}

function Overlay2() {
  return (
    <div className="bg-[#c6ff7f] relative rounded-[4px] shrink-0 w-full" data-name="Overlay">
      <div className="content-stretch flex flex-col items-start px-[10px] py-[6px] relative size-full">
        <Svg3 />
      </div>
    </div>
  );
}

function Link2() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0 w-[90px]" data-name="Link">
      <Overlay2 />
    </div>
  );
}

function Container5() {
  return (
    <div className="content-stretch flex gap-[10.5px] items-center relative shrink-0 w-full" data-name="Container">
      <Link />
      <Link1 />
      <Link2 />
    </div>
  );
}

function Container() {
  return (
    <div className="relative shrink-0 w-full" data-name="Container">
      <div className="bg-clip-padding border-0 border-[transparent] border-solid content-stretch flex flex-col gap-[20px] items-start relative size-full">
        <Container1 />
        <Container5 />
      </div>
    </div>
  );
}

function OverlayBorderOverlayBlur() {
  return (
    <div className="-translate-x-1/2 absolute bg-[rgba(18,21,30,0.4)] content-stretch flex flex-col items-start left-[calc(37.5%+23.5px)] max-w-[325px] p-[20px] rounded-[20px] top-[664px] w-[325px]" data-name="Overlay+Border+OverlayBlur">
      <Container />
    </div>
  );
}

function SimpleIconsFacebook() {
  return (
    <div className="-translate-x-1/2 -translate-y-1/2 absolute left-[calc(50%+0.5px)] size-[20px] top-1/2" data-name="simple-icons:facebook">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 20 20">
        <g clipPath="url(#clip0_1_589)" id="simple-icons:facebook">
          <path d={svgPaths.p699c500} fill="var(--fill-0, black)" id="Vector" />
        </g>
        <defs>
          <clipPath id="clip0_1_589">
            <rect fill="white" height="20" width="20" />
          </clipPath>
        </defs>
      </svg>
    </div>
  );
}

function Svg4() {
  return (
    <div className="overflow-clip relative shrink-0 size-[24px]" data-name="SVG">
      <SimpleIconsFacebook />
    </div>
  );
}

function Overlay3() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0" data-name="Overlay">
      <Svg4 />
    </div>
  );
}

function Link3() {
  return (
    <div className="bg-[#c6ff7f] content-stretch flex items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <Overlay3 />
    </div>
  );
}

function Svg5() {
  return (
    <div className="relative shrink-0 size-[24px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 24 24">
        <g id="SVG">
          <path d={svgPaths.pc760d00} fill="var(--fill-0, black)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay4() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0" data-name="Overlay">
      <Svg5 />
    </div>
  );
}

function Link4() {
  return (
    <div className="bg-[#c6ff7f] content-stretch flex items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <Overlay4 />
    </div>
  );
}

function Svg6() {
  return (
    <div className="relative shrink-0 size-[24px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 24 24">
        <g id="SVG">
          <path d={svgPaths.pc5d4400} fill="var(--fill-0, black)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay5() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0" data-name="Overlay">
      <Svg6 />
    </div>
  );
}

function Link5() {
  return (
    <div className="bg-[#c6ff7f] content-stretch flex items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <Overlay5 />
    </div>
  );
}

function Svg7() {
  return (
    <div className="relative shrink-0 size-[24px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 24 24">
        <g id="SVG">
          <path d={svgPaths.p217a0c10} fill="var(--fill-0, black)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay6() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0" data-name="Overlay">
      <Svg7 />
    </div>
  );
}

function Link6() {
  return (
    <div className="bg-[#c6ff7f] content-stretch flex items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <Overlay6 />
    </div>
  );
}

function Svg8() {
  return (
    <div className="relative shrink-0 size-[24px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 24 24">
        <g id="SVG">
          <path d={svgPaths.p25da1400} fill="var(--fill-0, black)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay7() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0" data-name="Overlay">
      <Svg8 />
    </div>
  );
}

function Link7() {
  return (
    <div className="bg-[#c6ff7f] content-stretch flex items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <Overlay7 />
    </div>
  );
}

function Frame2() {
  return (
    <div className="relative shrink-0">
      <div className="bg-clip-padding border-0 border-[transparent] border-solid content-stretch flex gap-[8px] items-start relative size-full">
        <Link3 />
        <Link4 />
        <Link5 />
        <Link6 />
        <Link7 />
      </div>
    </div>
  );
}

function Svg9() {
  return (
    <div className="h-[21px] relative shrink-0 w-[18px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 18 21">
        <g clipPath="url(#clip0_1_676)" id="SVG">
          <path d={svgPaths.p18e25b80} fill="var(--fill-0, black)" id="Vector" />
        </g>
        <defs>
          <clipPath id="clip0_1_676">
            <rect fill="white" height="21" width="18" />
          </clipPath>
        </defs>
      </svg>
    </div>
  );
}

function Overlay8() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0" data-name="Overlay">
      <Svg9 />
    </div>
  );
}

function Container6() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0" data-name="Container">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Regular',sans-serif] font-normal justify-center leading-[0] not-italic relative shrink-0 text-[14px] text-black w-[206px]">
        <p className="leading-[20px]">Toshkent sh, Alisher Navoiy ko‘chasi, 146A</p>
      </div>
    </div>
  );
}

function Link8() {
  return (
    <div className="bg-[#c6ff7f] relative rounded-[12px] shrink-0 w-[253px]" data-name="Link">
      <div className="bg-clip-padding border-0 border-[transparent] border-solid content-stretch flex gap-[5px] items-center px-[8px] py-[6px] relative size-full">
        <Overlay8 />
        <Container6 />
      </div>
    </div>
  );
}

function OverlayBorderOverlayBlur1() {
  return (
    <div className="-translate-x-1/2 absolute bg-[rgba(18,21,30,0.4)] content-stretch flex flex-col gap-[12px] items-center left-[calc(62.5%-6.5px)] max-w-[325px] p-[20px] rounded-[20px] top-[694px]" data-name="Overlay+Border+OverlayBlur">
      <Frame2 />
      <Link8 />
    </div>
  );
}

function Svg10() {
  return (
    <div className="relative shrink-0 size-[20px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 20 20">
        <g id="SVG">
          <path d={svgPaths.p89ade00} fill="var(--fill-0, white)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay9() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0 size-[24px]" data-name="Overlay">
      <Svg10 />
    </div>
  );
}

function Container7() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0" data-name="Container">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Regular',sans-serif] font-normal justify-center leading-[0] not-italic relative shrink-0 text-[14px] text-white whitespace-nowrap">
        <p className="leading-[20px]">Xavfsiz kontent</p>
      </div>
    </div>
  );
}

function Link9() {
  return (
    <div className="bg-[#060916] content-stretch flex gap-[5px] items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <div aria-hidden className="absolute border border-[rgba(255,255,255,0.1)] border-solid inset-0 pointer-events-none rounded-[12px]" />
      <Overlay9 />
      <Container7 />
    </div>
  );
}

function Svg11() {
  return (
    <div className="relative shrink-0 size-[20px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 20 20">
        <g id="SVG">
          <path d={svgPaths.p89ade00} fill="var(--fill-0, white)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay10() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0 size-[24px]" data-name="Overlay">
      <Svg11 />
    </div>
  );
}

function Container8() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0" data-name="Container">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Regular',sans-serif] font-normal justify-center leading-[0] not-italic relative shrink-0 text-[14px] text-white whitespace-nowrap">
        <p className="leading-[20px]">Audiokitoblar va videolar</p>
      </div>
    </div>
  );
}

function Link10() {
  return (
    <div className="bg-[#060916] content-stretch flex gap-[5px] items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <div aria-hidden className="absolute border border-[rgba(255,255,255,0.1)] border-solid inset-0 pointer-events-none rounded-[12px]" />
      <Overlay10 />
      <Container8 />
    </div>
  );
}

function Svg12() {
  return (
    <div className="relative shrink-0 size-[20px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 20 20">
        <g id="SVG">
          <path d={svgPaths.p89ade00} fill="var(--fill-0, white)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay11() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0 size-[24px]" data-name="Overlay">
      <Svg12 />
    </div>
  );
}

function Container9() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0" data-name="Container">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Regular',sans-serif] font-normal justify-center leading-[0] not-italic relative shrink-0 text-[14px] text-white whitespace-nowrap">
        <p className="leading-[20px]">Ota-ona nazorati</p>
      </div>
    </div>
  );
}

function Link11() {
  return (
    <div className="bg-[#060916] content-stretch flex gap-[5px] items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <div aria-hidden className="absolute border border-[rgba(255,255,255,0.1)] border-solid inset-0 pointer-events-none rounded-[12px]" />
      <Overlay11 />
      <Container9 />
    </div>
  );
}

function Svg13() {
  return (
    <div className="relative shrink-0 size-[20px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 20 20">
        <g id="SVG">
          <path d={svgPaths.p89ade00} fill="var(--fill-0, white)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay12() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0 size-[24px]" data-name="Overlay">
      <Svg13 />
    </div>
  );
}

function Container10() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0" data-name="Container">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Regular',sans-serif] font-normal justify-center leading-[0] not-italic relative shrink-0 text-[14px] text-white whitespace-nowrap">
        <p className="leading-[20px]">Kontent nazorati</p>
      </div>
    </div>
  );
}

function Link12() {
  return (
    <div className="bg-[#060916] content-stretch flex gap-[5px] items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <div aria-hidden className="absolute border border-[rgba(255,255,255,0.1)] border-solid inset-0 pointer-events-none rounded-[12px]" />
      <Overlay12 />
      <Container10 />
    </div>
  );
}

function Svg14() {
  return (
    <div className="relative shrink-0 size-[20px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 20 20">
        <g id="SVG">
          <path d={svgPaths.p89ade00} fill="var(--fill-0, white)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay13() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0 size-[24px]" data-name="Overlay">
      <Svg14 />
    </div>
  );
}

function Container11() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0" data-name="Container">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Regular',sans-serif] font-normal justify-center leading-[0] not-italic relative shrink-0 text-[14px] text-white whitespace-nowrap">
        <p className="leading-[20px]">Harakatlar tarixi</p>
      </div>
    </div>
  );
}

function Link13() {
  return (
    <div className="bg-[#060916] content-stretch flex gap-[5px] items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <div aria-hidden className="absolute border border-[rgba(255,255,255,0.1)] border-solid inset-0 pointer-events-none rounded-[12px]" />
      <Overlay13 />
      <Container11 />
    </div>
  );
}

function Svg15() {
  return (
    <div className="relative shrink-0 size-[20px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 20 20">
        <g id="SVG">
          <path d={svgPaths.p89ade00} fill="var(--fill-0, white)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay14() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0 size-[24px]" data-name="Overlay">
      <Svg15 />
    </div>
  );
}

function Container12() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0" data-name="Container">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Regular',sans-serif] font-normal justify-center leading-[0] not-italic relative shrink-0 text-[14px] text-white whitespace-nowrap">
        <p className="leading-[20px]">Bir tomonlama audio</p>
      </div>
    </div>
  );
}

function Link14() {
  return (
    <div className="bg-[#060916] content-stretch flex gap-[5px] items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <div aria-hidden className="absolute border border-[rgba(255,255,255,0.1)] border-solid inset-0 pointer-events-none rounded-[12px]" />
      <Overlay14 />
      <Container12 />
    </div>
  );
}

function Svg16() {
  return (
    <div className="relative shrink-0 size-[20px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 20 20">
        <g id="SVG">
          <path d={svgPaths.p89ade00} fill="var(--fill-0, white)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay15() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0 size-[24px]" data-name="Overlay">
      <Svg16 />
    </div>
  );
}

function Container13() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0" data-name="Container">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Regular',sans-serif] font-normal justify-center leading-[0] not-italic relative shrink-0 text-[14px] text-white whitespace-nowrap">
        <p className="leading-[20px]">Bildirishnomalarni ulash</p>
      </div>
    </div>
  );
}

function Link15() {
  return (
    <div className="bg-[#060916] content-stretch flex gap-[5px] items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <div aria-hidden className="absolute border border-[rgba(255,255,255,0.1)] border-solid inset-0 pointer-events-none rounded-[12px]" />
      <Overlay15 />
      <Container13 />
    </div>
  );
}

function Frame3() {
  return (
    <div className="content-stretch flex gap-[12px] items-center justify-center relative shrink-0">
      <Link9 />
      <Link10 />
      <Link11 />
      <Link12 />
      <Link13 />
      <Link14 />
      <Link15 />
    </div>
  );
}

function Svg17() {
  return (
    <div className="relative shrink-0 size-[20px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 20 20">
        <g id="SVG">
          <path d={svgPaths.p89ade00} fill="var(--fill-0, white)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay16() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0 size-[24px]" data-name="Overlay">
      <Svg17 />
    </div>
  );
}

function Container14() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0" data-name="Container">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Regular',sans-serif] font-normal justify-center leading-[0] not-italic relative shrink-0 text-[14px] text-white whitespace-nowrap">
        <p className="leading-[20px]">Hisobot</p>
      </div>
    </div>
  );
}

function Link16() {
  return (
    <div className="bg-[#060916] content-stretch flex gap-[5px] items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <div aria-hidden className="absolute border border-[rgba(255,255,255,0.1)] border-solid inset-0 pointer-events-none rounded-[12px]" />
      <Overlay16 />
      <Container14 />
    </div>
  );
}

function Svg18() {
  return (
    <div className="relative shrink-0 size-[20px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 20 20">
        <g id="SVG">
          <path d={svgPaths.p89ade00} fill="var(--fill-0, white)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay17() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0 size-[24px]" data-name="Overlay">
      <Svg18 />
    </div>
  );
}

function Container15() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0" data-name="Container">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Regular',sans-serif] font-normal justify-center leading-[0] not-italic relative shrink-0 text-[14px] text-white whitespace-nowrap">
        <p className="leading-[20px]">O‘yinlar</p>
      </div>
    </div>
  );
}

function Link17() {
  return (
    <div className="bg-[#060916] content-stretch flex gap-[5px] items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <div aria-hidden className="absolute border border-[rgba(255,255,255,0.1)] border-solid inset-0 pointer-events-none rounded-[12px]" />
      <Overlay17 />
      <Container15 />
    </div>
  );
}

function Svg19() {
  return (
    <div className="relative shrink-0 size-[20px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 20 20">
        <g id="SVG">
          <path d={svgPaths.p89ade00} fill="var(--fill-0, white)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay18() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0 size-[24px]" data-name="Overlay">
      <Svg19 />
    </div>
  );
}

function Container16() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0" data-name="Container">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Regular',sans-serif] font-normal justify-center leading-[0] not-italic relative shrink-0 text-[14px] text-white whitespace-nowrap">
        <p className="leading-[20px]">Vaqt nazorati</p>
      </div>
    </div>
  );
}

function Link18() {
  return (
    <div className="bg-[#060916] content-stretch flex gap-[5px] items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <div aria-hidden className="absolute border border-[rgba(255,255,255,0.1)] border-solid inset-0 pointer-events-none rounded-[12px]" />
      <Overlay18 />
      <Container16 />
    </div>
  );
}

function Svg20() {
  return (
    <div className="relative shrink-0 size-[20px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 20 20">
        <g id="SVG">
          <path d={svgPaths.p89ade00} fill="var(--fill-0, white)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay19() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0 size-[24px]" data-name="Overlay">
      <Svg20 />
    </div>
  );
}

function Container17() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0" data-name="Container">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Regular',sans-serif] font-normal justify-center leading-[0] not-italic relative shrink-0 text-[14px] text-white whitespace-nowrap">
        <p className="leading-[20px]">Konkurslar</p>
      </div>
    </div>
  );
}

function Link19() {
  return (
    <div className="bg-[#060916] content-stretch flex gap-[5px] items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <div aria-hidden className="absolute border border-[rgba(255,255,255,0.1)] border-solid inset-0 pointer-events-none rounded-[12px]" />
      <Overlay19 />
      <Container17 />
    </div>
  );
}

function Svg21() {
  return (
    <div className="relative shrink-0 size-[20px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 20 20">
        <g id="SVG">
          <path d={svgPaths.p89ade00} fill="var(--fill-0, white)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay20() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0 size-[24px]" data-name="Overlay">
      <Svg21 />
    </div>
  );
}

function Container18() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0" data-name="Container">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Regular',sans-serif] font-normal justify-center leading-[0] not-italic relative shrink-0 text-[14px] text-white whitespace-nowrap">
        <p className="leading-[20px]">Yosh filtri</p>
      </div>
    </div>
  );
}

function Link20() {
  return (
    <div className="bg-[#060916] content-stretch flex gap-[5px] items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <div aria-hidden className="absolute border border-[rgba(255,255,255,0.1)] border-solid inset-0 pointer-events-none rounded-[12px]" />
      <Overlay20 />
      <Container18 />
    </div>
  );
}

function Svg22() {
  return (
    <div className="relative shrink-0 size-[20px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 20 20">
        <g id="SVG">
          <path d={svgPaths.p89ade00} fill="var(--fill-0, white)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay21() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0 size-[24px]" data-name="Overlay">
      <Svg22 />
    </div>
  );
}

function Container19() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0" data-name="Container">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Regular',sans-serif] font-normal justify-center leading-[0] not-italic relative shrink-0 text-[14px] text-white whitespace-nowrap">
        <p className="leading-[20px]">Yoshga mos kontent</p>
      </div>
    </div>
  );
}

function Link21() {
  return (
    <div className="bg-[#060916] content-stretch flex gap-[5px] items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <div aria-hidden className="absolute border border-[rgba(255,255,255,0.1)] border-solid inset-0 pointer-events-none rounded-[12px]" />
      <Overlay21 />
      <Container19 />
    </div>
  );
}

function Svg23() {
  return (
    <div className="relative shrink-0 size-[20px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 20 20">
        <g id="SVG">
          <path d={svgPaths.p89ade00} fill="var(--fill-0, white)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay22() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0 size-[24px]" data-name="Overlay">
      <Svg23 />
    </div>
  );
}

function Container20() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0" data-name="Container">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Regular',sans-serif] font-normal justify-center leading-[0] not-italic relative shrink-0 text-[14px] text-white whitespace-nowrap">
        <p className="leading-[20px]">Jonli joylashuv</p>
      </div>
    </div>
  );
}

function Link22() {
  return (
    <div className="bg-[#060916] content-stretch flex gap-[5px] items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <div aria-hidden className="absolute border border-[rgba(255,255,255,0.1)] border-solid inset-0 pointer-events-none rounded-[12px]" />
      <Overlay22 />
      <Container20 />
    </div>
  );
}

function Svg24() {
  return (
    <div className="relative shrink-0 size-[20px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 20 20">
        <g id="SVG">
          <path d={svgPaths.p89ade00} fill="var(--fill-0, white)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay23() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0 size-[24px]" data-name="Overlay">
      <Svg24 />
    </div>
  );
}

function Container21() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0" data-name="Container">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Regular',sans-serif] font-normal justify-center leading-[0] not-italic relative shrink-0 text-[14px] text-white whitespace-nowrap">
        <p className="leading-[20px]">Hudud nazorati</p>
      </div>
    </div>
  );
}

function Link23() {
  return (
    <div className="bg-[#060916] content-stretch flex gap-[5px] items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <div aria-hidden className="absolute border border-[rgba(255,255,255,0.1)] border-solid inset-0 pointer-events-none rounded-[12px]" />
      <Overlay23 />
      <Container21 />
    </div>
  );
}

function Svg25() {
  return (
    <div className="relative shrink-0 size-[20px]" data-name="SVG">
      <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 20 20">
        <g id="SVG">
          <path d={svgPaths.p89ade00} fill="var(--fill-0, white)" id="Vector" />
        </g>
      </svg>
    </div>
  );
}

function Overlay24() {
  return (
    <div className="bg-[rgba(255,255,255,0.06)] content-stretch flex flex-col items-start p-[2px] relative rounded-[8px] shrink-0 size-[24px]" data-name="Overlay">
      <Svg25 />
    </div>
  );
}

function Container22() {
  return (
    <div className="content-stretch flex flex-col items-start relative shrink-0" data-name="Container">
      <div className="[word-break:break-word] flex flex-col font-['Inter:Regular',sans-serif] font-normal justify-center leading-[0] not-italic relative shrink-0 text-[14px] text-white whitespace-nowrap">
        <p className="leading-[20px]">Ekranni ko‘rish</p>
      </div>
    </div>
  );
}

function Link24() {
  return (
    <div className="bg-[#060916] content-stretch flex gap-[5px] items-center px-[8px] py-[6px] relative rounded-[12px] shrink-0" data-name="Link">
      <div aria-hidden className="absolute border border-[rgba(255,255,255,0.1)] border-solid inset-0 pointer-events-none rounded-[12px]" />
      <Overlay24 />
      <Container22 />
    </div>
  );
}

function Frame4() {
  return (
    <div className="content-stretch flex gap-[12px] items-center justify-center relative shrink-0 w-full">
      <Link16 />
      <Link17 />
      <Link18 />
      <Link19 />
      <Link20 />
      <Link21 />
      <Link22 />
      <Link23 />
      <Link24 />
    </div>
  );
}

function Frame5() {
  return (
    <div className="-translate-x-1/2 absolute content-stretch flex flex-col h-[82px] items-center justify-between left-[calc(50%+0.5px)] top-[918px]">
      <Frame3 />
      <Frame4 />
    </div>
  );
}

export default function Main() {
  return (
    <div className="bg-[#060916] relative size-full" data-name="Main">
      <div className="absolute inset-[-4.63%_-35.97%_-6.48%_-6.81%]" data-name="Vector">
        <svg className="absolute block inset-0 size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 2056 1200">
          <path clipRule="evenodd" d={svgPaths.p9e29a00} fill="url(#paint0_linear_1_654)" fillOpacity="0.14" fillRule="evenodd" id="Vector" />
          <defs>
            <linearGradient gradientUnits="userSpaceOnUse" id="paint0_linear_1_654" x1="1028" x2="1028" y1="0" y2="1200">
              <stop stopColor="white" stopOpacity="0.2" />
              <stop offset="1" stopColor="white" stopOpacity="0" />
            </linearGradient>
          </defs>
        </svg>
      </div>
      <Frame1 />
      <Group1 />
      <div className="absolute h-[237px] left-[calc(8.33%+123px)] top-[659px] w-[961px]">
        <div className="absolute inset-[-18.57%_-4.58%]">
          <svg className="block size-full" fill="none" preserveAspectRatio="none" viewBox="0 0 1049 325">
            <g filter="url(#filter0_f_1_685)" id="Ellipse 3">
              <ellipse cx="524.5" cy="162.5" fill="var(--fill-0, #060916)" rx="480.5" ry="118.5" />
            </g>
            <defs>
              <filter colorInterpolationFilters="sRGB" filterUnits="userSpaceOnUse" height="325" id="filter0_f_1_685" width="1049" x="0" y="0">
                <feFlood floodOpacity="0" result="BackgroundImageFix" />
                <feBlend in="SourceGraphic" in2="BackgroundImageFix" mode="normal" result="shape" />
                <feGaussianBlur result="effect1_foregroundBlur_1_685" stdDeviation="22" />
              </filter>
            </defs>
          </svg>
        </div>
      </div>
      <OverlayBorderOverlayBlur />
      <OverlayBorderOverlayBlur1 />
      <Frame5 />
    </div>
  );
}