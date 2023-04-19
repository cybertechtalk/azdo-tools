import sys
from time import time, sleep
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.common.exceptions import NoSuchElementException
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as expect
from selenium.webdriver.common.by import By

# initial config:
started = time()
driver_options = webdriver.ChromeOptions()
driver_options.add_argument('--headless')
driver_options.add_argument('--incognito')
driver_options.add_argument('--no-sandbox')
driver_options.add_argument('--no-proxy-server')
driver_options.add_argument("--window-size=1280, 800")

s = Service('C:/ProgramData/chocolatey/bin/chromedriver.exe')
driver = webdriver.Chrome(service=s, options=driver_options)
wait = WebDriverWait(driver=driver, timeout=60)


def validate_swagger(uri):
    driver.get(uri)
    try:
        # wait for UI wrapper on the botton of the screen:
        wait.until(expect.visibility_of_element_located(
            (By.XPATH, "//div[@class='validation-ui-wrapper']")
        ))
        print(f'##[debug]{uri} loaded in: {round(time() - started, 2)}s.')
    except Exception as e:
        print('##[error]unable to render swagger definition', str(e))
        sys.exit(1)
    else:
        sleep(2)
        is_error, is_warning = True, True
        try:
            errors = driver.find_element(
                By.XPATH, "//span[@class='errors-value']")
        except NoSuchElementException:
            is_error = False
        try:
            warnings = driver.find_element(
                By.XPATH, "//span[@class='warnings-value']")
        except NoSuchElementException:
            is_warning = False

        wrn_msg = "##[debug]no warnings found" if is_warning == False else f"##[error]number of warnings: {warnings.text}"
        err_msg = "##[debug]no errors found" if is_error == False else f"##[error]number of errors: {errors.text}"
        print(wrn_msg)
        print(err_msg)
        if is_warning or is_error:
            print('##[error]returning with exit code 1')
            sys.exit(1)

    print('##[debug]finished sucessfully')


if __name__ == '__main__':
    uri = sys.argv[1]
    validate_swagger(uri=uri)
