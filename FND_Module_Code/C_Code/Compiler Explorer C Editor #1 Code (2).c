#include <stdint.h>

#define __IO volatile

typedef struct {
    __IO uint32_t MODER;
    __IO uint32_t ODR;
} GPO_TypeDef;

typedef struct {
    __IO uint32_t MODER;
    __IO uint32_t IDR;
} GPI_TypeDef;

typedef struct {
    __IO uint32_t MODER;
    __IO uint32_t IDR;
    __IO uint32_t ODR;
} GPIO_TypeDef;

typedef struct {
    __IO uint32_t FCR;  // Enable 신호 설정
    __IO uint32_t FDR;  // Fnd 설정
    __IO uint32_t FPR;  // Dot 설정
} FND_TypeDef;

#define APB_BASEADDR    0x10000000
#define GPOA_BASEADDR   (APB_BASEADDR + 0x1000)
#define GPIB_BASEADDR   (APB_BASEADDR + 0x2000)
#define GPIOC_BASEADDR  (APB_BASEADDR + 0x3000)
#define GPIOD_BASEADDR  (APB_BASEADDR + 0x4000)
#define FND_BASEADDR    (APB_BASEADDR + 0x5000)

#define GPOA    ((GPO_TypeDef *) GPOA_BASEADDR)
#define GPIB    ((GPI_TypeDef *) GPIB_BASEADDR)
#define GPIOC   ((GPIO_TypeDef *) GPIOC_BASEADDR)
#define GPIOD   ((GPIO_TypeDef *) GPIOD_BASEADDR)
#define FND     ((FND_TypeDef *) FND_BASEADDR)

#define FND_ON   1
#define FND_OFF  0

// 함수 선언
void delay_ms(int ms);
void FND_init(FND_TypeDef *FNDx, uint32_t ON_OFF);
void FND_dp(FND_TypeDef *FNDx, uint32_t dp_val);
uint32_t Switch_read(GPIO_TypeDef *GPIOx);

int main()
{
    uint32_t dot_timer = 0;
    uint32_t fnd_timer = 0;
    uint8_t dot_state = 0;

    while (1)
    {
        if (Switch_read(GPIOD) & (1 << 0)) {
            FND_init(FND, FND_ON);

            if (fnd_timer >= 100) {
                if (Switch_read(GPIOD) & (1 << 1)) {
                    FND->FDR = (FND->FDR == 0) ? 9999 : FND->FDR - 1;
                } else {
                    FND->FDR = (FND->FDR == 9999) ? 0 : FND->FDR + 1;
                }
                fnd_timer = 0;
            }

            if (dot_timer >= 500) {
                dot_state = !dot_state;

                // dp[1]만 깜빡이도록 수정 (bit 1 only)
                uint32_t dp_val = (dot_state) ? 0x02 : 0x00;
                FND_dp(FND, dp_val);

                dot_timer = 0;
            }

            delay_ms(1);
            fnd_timer++;
            dot_timer++;
        } else {
            FND_init(FND, FND_OFF);
        }
    }

    return 0;
}

void delay_ms(int ms)
{
    volatile uint32_t temp;
    for (int i = 0; i < ms; i++) {
        temp = 0;
        for (int j = 0; j < 1000; j++) {
            temp++;
        }
    }
}

void FND_init(FND_TypeDef *FNDx, uint32_t ON_OFF)
{
    FNDx->FCR = ON_OFF;
}

void FND_dp(FND_TypeDef *FNDx, uint32_t dp_val)
{
    // dp[1]만 반영하고, 나머지는 꺼지게 강제함
    FNDx->FPR = dp_val;
}

uint32_t Switch_read(GPIO_TypeDef *GPIOx)
{
    return GPIOx->IDR;
}
